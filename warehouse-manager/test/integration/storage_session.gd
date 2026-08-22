extends Node

## Integration layer: the storage round trip, across two real processes.
##
## Sibling to carry_session.gd rather than folded into it — carry's
## choreography is already a full linear script, and storage is a different
## scenario entirely. Follows the same design rules as that file (see its own
## doc comment for the reasoning): drives the real keypress path through
## [method Carrier.try_toggle_hold], instances the real test_room.tscn rather
## than a bespoke scene, waits on state rather than time, and has its own
## port so it can never fight carry_session's 27099 or a live game's 27015.
##
## ⚠ A few of this scenario's exact numbers do not survive being simulated
## step by step the way the plan first wrote them — filling a cell to eight
## and then asserting it empty two steps later, or an occupancy of 1 sitting
## alongside a crate count that only matches a completely different point in
## the sequence. Every *property* the plan names is still proven below —
## place, a cell taking more than one, a full cell refusing without a drop, a
## dragged crate refused above the floor row, LIFO order, and the body budget
## — the exact figures are just derived from what this sequence actually
## does rather than copied from the plan text. See 01-04-SUMMARY.md for the
## specifics that changed.
##
## Two peers, host-leads/client-follows and back again, entirely through
## replicated state:
##   1. Host racks crate_0 into CELL_A. Client waits for the occupancy to
##      change and checks its own copy — the real proof of "the body left the
##      world on every peer", not just the host's say-so.
##   2. Client racks crate_1 into the SAME cell. Host waits and checks back —
##      proves a cell holds more than one (ADR 18), not one-slot-per-cell.
##   3. Host tops CELL_B up to capacity through the referee's own broadcast
##      RPC directly, with synthetic ids that were never real crates. This is
##      setup, not the thing under test, but it travels over the same wire a
##      real placement does, so both peers agree it is full.
##   4. Client grabs a loose crate and is refused by the full cell — proven on
##      the real keypress path, and proven it does not silently become a
##      drop.
##   5. Client drags a different crate and is refused by CELL_A, which is not
##      floor level (ADR 19) — a carried crate can reach it (steps 1 and 2
##      just did); a dragged one physically cannot.
##   6. Host retrieves twice from CELL_A with empty hands between each. The
##      rack's own bookkeeping (rack.occupant()) pops in the exact reverse of
##      the order the two ids went in — the mechanic ADR 18 exists for. Proven
##      through that bookkeeping rather than through the id of whatever crate
##      ends up in the retriever's hands, because request_retrieve always
##      mints a fresh body — the placed one was freed outright, ADR 14, so
##      nothing kept the original in reserve to hand back. The cell ends
##      empty, which the client independently confirms on its own copy.
##
## 01-07 continues the same two peers straight on from step 6, with its own
## numbered steps 7-9 (shed, then stack) — see the block of constants below
## for the detail, kept there rather than here so the exact cell numbers and
## the reasoning behind them sit next to each other.
##
## 02-06 continues straight on again with steps 13-16: STORE-07's round-trip
## invariant proven field by field, a Medium round trip, heavy retrieval
## (ADR 19's mass rule deciding DRAG unasked), and a late joiner's snapshot
## carrying real contents, not just counts — see the constants block above
## [method _run_host] for the same reason 01-07's own steps sit there rather
## than here.

const WORLD_SCENE := preload("res://scenes/levels/test_room.tscn")

## Deliberately neither carry_session's 27099 nor a live game's 27015.
const TEST_PORT := 27097
## Raised 15000 -> 20000 by 02-06 (steps 13-15's own dense retrieve/place
## sequence), then 20000 -> 45000 by 02-08: steps 17-21 add five more
## placements/retrievals on top of an already-long scenario, and by that
## point in a real run the client's own incoming RPC queue can be measured
## running many real seconds behind the host's own send order — the exact
## same symptom 02-06 already named ("an otherwise-clean run failing on a
## client-side wait for a placement the host's own log shows landed
## correctly, just not within the old budget"), now at a larger scale.
## Confirmed by a direct diagnostic (a temporary print in
## CarryAuthority._cell_filled, never committed): every RPC this file sends
## arrives, in the correct order, with no drops and no duplicates — only
## LATE, and later still the longer the scenario has already run. This is a
## budget problem, not a correctness one; see this constant's own history for
## why the fix is a bigger number, not a different mechanism.
const STEP_TIMEOUT_MS := 45000
const EXPECTED_PLAYERS := 2
## TestRoom's own starting batch (test_room.gd's crate_count), raised to 12 for
## the gate playtest protocol (2026-08-21) — two rows of six rather than one
## row of twelve; see CRATE_ROW2_ORIGIN's own doc comment for why — then to 17
## for 02-04's mixed heavy row (HEAVY_ROW_ORIGIN, crate_12..crate_16). Every
## crate_0..crate_5 name and position this file already depends on is
## unchanged — the second row (crate_6..crate_11) and the heavy row
## (crate_12..crate_16) are both unclaimed by any step below, same as row 1's
## own untouched crate_1 slot before it.
const EXPECTED_CRATES := 17

## The rack this session racks into and retrieves from. Node name is protocol
## (ADR 12) — must match the level's actual Racks/rack_wall exactly.
const RACK_PATH := "Racks/rack_wall"
## The wave 7 gate's three regression steps (10-12, below) all use
## rack_island rather than rack_wall — untouched by every step above this
## point, so they cannot collide with rack_wall's own already-exercised cell
## states. The same cell-index topology applies unchanged: StorageGrid's
## arithmetic is rack-agnostic, and CELL_A/CELL_B/CELL_TOP_A/CELL_TOP_B below
## are reused as-is against this second rack — depth=1 is the near, aimable
## side approached from +Z on rack_island too, for the same reason rack_wall's
## own note on those constants explains.
const RACK2_PATH := "Racks/rack_island"
## Both level 1 (StorageGrid.cell_coords(i).z == 1, not floor) — deliberately
## not level 0, so a real carried placement into either one is itself a small
## proof that "a carried crate can reach any cell" (a dragged one cannot
## reach either).
##
## ⚠ Both also depth=1 (StorageGrid.cell_coords(i).y == 1), and that part is
## not a free choice. A rack's CellSensor volumes are permanent aim targets,
## present whether or not their cell holds anything, and rack_wall is backed
## directly onto the room's north wall — so the only side a player can ever
## stand on is the depth=1 (south-facing) row's own side. Aiming at a
## depth=0 cell from there means the ray has to pass through the depth=1
## cell directly in front of it first, and an Area3D blocks a raycast
## regardless of its monitoring flags, so a depth=0 cell on this particular
## rack is permanently unaimable no matter what it holds. Discovered by this
## scenario timing out solid on cell 5 (depth 0) before this was cell 7.
const CELL_A := 7
const CELL_B := 6

## How far past the cell centre a player stands to interact with it, along Z.
##
## Derived, not guessed. At 1.3 m the held crate (riding 1.15 m in front of
## the camera) would sit inside the rack's own deck, breaking the hold for
## reasons that look like a physics bug rather than a bad stand position. At
## 2.0 m the held crate clears the deck face, the camera sits about 2.05 m
## from the cell centre — inside both the 2.0 m GrabRay and the referee's
## 3.0 m PLACE_REACH — and aiming at rack.cell_to_global_position(i) resolves
## back to cell i. If an assertion below ever fails, re-check this first.
## (PLACE_REACH was 2.6 until the wave 7 gate found it too tight for a
## ray-limited aim near the ray's own edge — see MAX_RANGE_STAND_OFFSET_Z's
## own doc comment below, and carry_authority.gd's. The whole reach chain —
## GrabRay, GRAB_REACH, PLACE_REACH — was shortened again at the wave 7 gate,
## 2026-08-21 (NJ): 2.5 m ray / 2.5 m GRAB_REACH / 3.5 m PLACE_REACH each
## became 2.0 / 2.0 / 3.0. This constant's own 2.0 m needed no change — it was
## already the closer, deck-clearance-driven number — only the numbers it is
## compared against here moved.)
const RACK_STAND_OFFSET_Z := 2.0
## Two different lateral offsets so host and client never occupy the exact
## same point when both are near the rack in the same window — the same
## reason carry_session gives its two roles different Z offsets around the
## crate they share.
const HOST_LATERAL := 0.4
const CLIENT_LATERAL := -0.4
## How far along Z a player stands from the crate row to grab a loose crate.
##
## Re-derived at the wave 7 gate (2026-08-21) when GRAB_REACH shortened
## 2.5 -> 2.0 m — this is a GRAB_REACH check (carry_authority.gd's
## request_grab measures camera -> crate.global_position directly), not a
## PLACE_REACH one, so it has no half-diagonal margin to lean on the way a
## cell placement does. [method _grab] stands the player level with the
## crate on X, so this is the only horizontal component — but the vertical
## drop is what actually eats the budget: CameraPivot sits 1.6 m above
## STAND_HEIGHT (1.7 m up), and a crate that spawned at the row's y=0.6 has
## long since fallen and settled to its real rest height, y=0.25 (floor top
## at y=0.0, a Small's own half-height 0.25 - see carry_session.gd's
## LIFT_MIN_Y doc for the same number confirmed independently). That is a
## fixed 1.45 m vertical leg regardless of how close this offset stands the
## player, so sqrt(offset^2 + 1.45^2) <= 2.0 caps offset at about 1.38 m with
## NO margin. 1.5 cleared the old 2.5 m GRAB_REACH by 0.41 m; 1.15 clears the
## new 2.0 m by about 0.15 m (distance ~1.85 m) — comparable margin, closer
## stand. Every crate this file grabs (crate_0 through the max-range probe)
## sits at this same row height, so this one number covers all of them.
const GRAB_STAND_OFFSET_Z := 1.15
const STAND_HEIGHT := 0.1
## How long the host waits, after its own last network-relevant action,
## before quitting. get_tree().quit() does not flush a pending reliable send
## first, so finishing immediately after issuing one can tear the peer down
## before it actually reaches the client -- see the call site.
const EXIT_SETTLE_MS := 500

## Crate name allocation within this scenario's own world (a separate process
## pair from carry_session, so its own crate counter starts at 0 too — these
## names do not collide with carry_session's table).
const CRATE_HOST_NAME := "crate_0"
const CRATE_CLIENT_NAME := "crate_1"
const CRATE_FULL_ATTEMPT_NAME := "crate_2"
const CRATE_DRAG_ATTEMPT_NAME := "crate_3"

## Ids for CELL_B's synthetic fill. Far outside the range TestRoom ever
## mints (0..5 for six starting crates), so they can never collide with, or
## be mistaken for, a real crate.
const FILLER_ID_START := 9000
const FILLER_COUNT := 8
## _cell_filled (02-06) carries a whole record so Rack.apply_cell_filled can
## store it rather than a hard-coded fallback (see that method's own doc
## comment) -- these fillers were never real crates, so this is a plain,
## distinct placeholder category rather than any real CargoCatalogue row.
## CargoCatalogue.mint() tolerates an unknown category (fragility/mass/value
## all default to 0), so a synthetic filler record still round-trips through
## the exact same to_dict()/from_dict() shape a real crate's does. All eight
## share it, which is what "fill one cell to capacity" means under atomicity
## (ADR 18).
const FILLER_KIND := &"filler"
## Placeholders for CargoCatalogue.mint()'s manifest-only parameters -- these
## fillers are never handed over or inspected for a contract, so any legal
## values do.
const FILLER_STORE_UNTIL_DAY := 1
const FILLER_OWNER := &"test_client"
const FILLER_CONTRACT_DAYS := 1

## --- 01-07: the shed, and the stack. ---
##
##   7. Host fills two top-row cells with two of the six starting crates that
##      nothing above ever names (crate_4, crate_5 sit untouched in the row
##      the whole time - reserved for exactly this), through the same real
##      grab-and-place choreography steps 1-2 used.
##   8. Host launches a third crate at the rack fast enough to clear
##      Rack.shed_impact_speed, by direct property manipulation rather than a
##      grab - the same determinism trick carry_session.gd's own _take()
##      documents: a crate is always simulated for real on the host, so
##      setting its transform and velocity by hand is a legitimate host
##      action. Both peers then assert: both top-row cells empty; cell 6 (not
##      top row) untouched, proving the bound; the loose-crate count up by
##      exactly two, a delta against what was recorded before the impact, not
##      an absolute; and both racked visuals gone.
##   9. The same direct-manipulation trick places one loose crate directly
##      above another, away from every other fixture, and both peers wait for
##      the upper one to settle above the lower rather than sink through it -
##      success criterion 5's first half. The "blocks pathing" half is a
##      finding for a human, not a test - see 01-07-SUMMARY.md.
##
## Steps 10-12 (added 2026-08-21) are three regressions found live at the
## wave 7 gate playtest, all against rack_island rather than rack_wall so
## they cannot collide with anything above: retrieving a crate does not shed
## a still-loaded neighbour cell in the same top row; a crate stranded inside
## a rack's own CellSensor volume is grabbable through the real interact
## path; and a genuine maximum-range aim succeeds rather than being silently
## refused. See the "Wave 7 gate regressions" block comment above
## MAX_RANGE_STAND_OFFSET_Z for the full reasoning behind each.

## Both level 2 (top row - StorageGrid.cell_coords(i).z == RACK_LEVELS - 1)
## and depth 1, the same aimable side CELL_A/CELL_B already established
## above: rack_wall's depth-0 row is permanently unaimable regardless of
## level (the front row's own CellSensor volumes block the ray to whatever
## is behind them), so a depth-0 top-row cell would never be reachable
## through the real grab-and-place path this step deliberately uses.
const CELL_TOP_A := 10
const CELL_TOP_B := 11

## Two of the six starting crates nothing above this point ever names by
## constant - see the step 7 note above for why that is deliberate rather
## than an oversight.
const CRATE_SHED_A_NAME := "crate_4"
const CRATE_SHED_B_NAME := "crate_5"

## Comfortably above Rack.shed_impact_speed (4.0) so a frame or two of drag
## before body_entered fires can never flake the assertion.
const IMPACT_SPEED := 8.0
## Rack-local, along the rack's own +Z - the same axis RACK_STAND_OFFSET_Z
## stands a player on, and the side ImpactSensor's own centre (z=1.0) sits
## proud of at its far edge (z=1.45, half its 0.9 depth either side of
## centre). 1.9 clears that with margin, so the crate starts genuinely
## outside the sensor and body_entered fires as it arrives rather than on
## the very first frame of the scenario.
const IMPACT_START_OFFSET_Z := 1.9
## Rack-local height for the impact - inside ImpactSensor's y-span (1.3 local
## centre, 1.2 either side) with margin on both sides.
const IMPACT_HEIGHT := 1.5
## Rack-local, along the rack's own +X. Centred on the rack's own width
## (matches ImpactSensor's own x centre) and deliberately not 0 - the corner
## uprights (rack.tscn's UprightBackLeft/Right) sit right at the rack's own
## x=0 and x=2 edges, and a crate launched with no lateral offset spawns
## already overlapping one of them, which flings it in a direction this test
## cannot predict rather than sending it into the sensor. 1.0 keeps the whole
## crate (0.25 half-extent) inside the 0.1-1.9 aisle between them.
const IMPACT_LATERAL_OFFSET := 1.0

## Clear floor for the stacking check, away from the racks, the zones, the
## crate row and PARK_POINT alike.
const STACK_BASE := Vector3(4.0, 0.25, -4.0)
## How far above STACK_BASE the upper crate starts - comfortably clear so it
## visibly falls onto the lower one rather than starting embedded in it.
const STACK_DROP_HEIGHT := 0.55
## The stacked crate's own half-height (0.25) plus the lower crate's, less a
## small margin - above this it is resting on top; at or below it, it has
## sunk into (or through) the lower crate.
const STACK_SETTLED_MIN_Y := 0.45

## --- Wave 7 gate regressions (10-12), added 2026-08-21. ---
##
## Three defects diagnosed live at the gate playtest, each fixed in game code
## and proven here against the real path rather than only by reasoning about
## the fix:
##
##   10. A cell taken more than one, retrieval this time: rack_island's own
##       top row is filled exactly as step 7 filled rack_wall's, then ONE of
##       the two loaded cells is retrieved through the real request_retrieve
##       path. Before the fix (Crate._spawn_ms / age_ms, Rack.MINT_GRACE_MS),
##       the retrieved crate mints at its cell's own centre — inside the
##       rack's ImpactSensor — and the hold spring accelerates it past
##       shed_impact_speed while still overlapping, shedding the row it was
##       just taken from (reproduced live: retrieving from a loaded top row
##       shed the row). Proven the same way step 8 already proves a real shed
##       — occupied_count on the untouched neighbour cell, and a crate-count
##       delta against a baseline captured immediately before — rather than
##       inventing a second observation mechanism for "no shed happened".
##   11. A loose crate resting inside a rack's CellSensor volume (a shed
##       crate landing there happened twice in play) used to be permanently
##       unaimable: the combined ray hit the sensor's own surface first,
##       resolved to an empty cell, and try_toggle_hold did nothing — and
##       supply conservation did not save it, since recovery only fires
##       below the world. Carrier._aim()'s empty-handed cargo-only probe is
##       the fix; this teleports a crate into a cell, lets it fall and settle
##       exactly as a shed crate would, then grabs it through the real
##       try_toggle_hold path — not by calling anything lower-level.
##   12. A genuine maximum-range aim: PLACE_REACH used to measure
##       camera → cell CENTRE against a reach barely past GrabRay's own 2.5 m
##       camera → hit-point limit (both numbers as they stood at the time),
##       so a real aim near the ray's own edge could paint the highlight
##       green and then be silently refused. MAX_RANGE_STAND_OFFSET_Z stands
##       the player far enough back that camera → cell face lands near the
##       ray's own edge while camera → cell centre lands past the OLD, buggy
##       2.6 m PLACE_REACH — this placement would have failed before the fix
##       and must succeed now. Re-derived at the wave 7 gate (2026-08-21,
##       NJ) when the whole reach chain shortened again — ray and
##       GRAB_REACH 2.5 → 2.0 m, PLACE_REACH 3.5 → 3.0 m — see
##       MAX_RANGE_STAND_OFFSET_Z's own doc comment below for the new
##       numbers this regression now proves against.

## Regression 12's stand offset, deliberately farther back than
## RACK_STAND_OFFSET_Z's comfortable 2.0 m. Solved the same way
## RACK_STAND_OFFSET_Z's own doc comment was: numerically, from the
## stand → camera → face/centre geometry, not guessed.
##
## Re-derived at the wave 7 gate (2026-08-21) for the new 2.0 m ray / 3.0 m
## PLACE_REACH (was 2.85 m, for the old 2.5 m ray / 3.5 m PLACE_REACH — see
## the "12." bullet above). At 2.35 m: camera to the cell's own face lands at
## ≈1.89 m — just inside the new 2.0 m GrabRay, the same "near the ray's own
## edge" band the original 2.85 m targeted (then 2.3-2.45 m out of a 2.5 m
## ray; now 1.8-1.95 m out of a 2.0 m one) — so the ray still connects, but
## barely, which is the point. Camera to the cell CENTRE — what PLACE_REACH
## actually checks — lands at ≈2.38 m: comfortably inside the new 3.0 m
## PLACE_REACH, which alone would tolerate up to the ray's own 2.87 m worst
## case (PLACE_REACH's own doc comment). The binding constraint at this
## offset is the ray actually reaching the cell at all, not PLACE_REACH —
## exactly the case this regression exists to prove.
const MAX_RANGE_STAND_OFFSET_Z := 2.35

const CRATE_GATE_TOP_A_NAME := "crate_6"
const CRATE_GATE_TOP_B_NAME := "crate_7"
const CRATE_GATE_STRANDED_NAME := "crate_8"
const CRATE_GATE_MAX_RANGE_NAME := "crate_9"

## Where steps 10-11 release what they were holding — PARK_POINT itself is
## calibrated for rack_wall's own approach corridor, over 11 m from
## rack_island, and walking a release there and back (measured: this scenario
## timed out solid on step 11's cross-peer check the first time it used
## PARK_POINT — the round trip left too little of the client's own 15 s
## window for a 20 Hz replication tick to actually land before the crate was
## released again) buys nothing here: steps 10-12 never aim at rack_wall
## again, so there is no earlier corridor left to protect from a dropped
## crate. East of rack_island's own footprint (x=[6.5,8.5]) rather than north
## of it, clear of both CELL_A's and CELL_B's own approach stand points
## (both north of the rack, around z=4.5-5.35) and of the ImpactSensor's own
## x-extent (max 8.6).
const GATE_PARK_POINT := Vector3(9.5, STAND_HEIGHT, 2.5)
## How long step 11 holds crate_8 before releasing it, deliberately — not a
## state wait, but the same reasoning EXIT_SETTLE_MS already relies on: the
## client's own replicated view needs at least one 20 Hz sync tick to see
## the hold before it ends again.
const GATE_HOLD_CONFIRM_MS := 500

## Step 11's own approach offset, added at the wave 7 gate (2026-08-21) when
## GRAB_REACH shortened 2.5 -> 2.0 m. RACK_STAND_OFFSET_Z's default is tuned
## for a PLACE_REACH check against the cell's mathematical CENTRE — fine for
## every placement/retrieval in this file, but step 11 grabs a real crate
## (a GRAB_REACH check, camera -> crate.global_position), and this crate did
## not stay at the centre: it fell out of CELL_A's own sensor volume and
## settled on the rack's DeckMid shelf below (local/world y=1.025, from
## rack.tscn — a Small's own half-height, 0.25, puts its resting centre at
## y≈1.275), 0.225 m below the cell's mathematical centre (y=1.5) that
## RACK_STAND_OFFSET_Z's own margin was computed against. That extra vertical
## drop, combined with CameraPivot sitting 1.7 m up (STAND_HEIGHT + 1.6) and
## HOST_LATERAL's 0.4 m sideways offset, pushed camera -> crate to ≈2.08 m at
## the default 2.0 m offset — inside the OLD 2.5 m GRAB_REACH with room to
## spare, but past the new 2.0 m one. At 1.7 m: sqrt(0.4² + 0.425² + 1.7²) ≈
## 1.80 m, comfortably inside the new GRAB_REACH with margin — and still well
## clear of the rack's own accessible face (world z=3.0 for this cell; this
## stands the player at world z=4.2), so it does not put the capsule inside
## the frame.
const STRANDED_STAND_OFFSET_Z := 1.7

## --- 02-06: STORE-07, the round trip (steps 13-16). ---
##
##   13. The round trip, field for field -- the centrepiece. crate_10
##       (glassware, the highest-fragility category in the whole table) is
##       racked with two Phase-3-owned fields deliberately mutated first (a
##       nonzero drag_distance, and a genuinely patched condition -- actual
##       != apparent, GOODS-05's whole point) through the real
##       Carrier.try_toggle_hold() path, never the referee directly
##       (test/README.md's own reasoning: a test that called the referee
##       directly passed while the aim ray was broken). Both peers assert
##       the racked cell's own stored record matches, field by field, naming
##       each one; then it is retrieved through the real path and both peers
##       assert the FRESHLY MINTED crate's record matches too -- every field
##       except id, which legitimately changes on every retrieval by design
##       (TestRoom.spawn_crate_at always mints a fresh one; REQUIREMENTS.md's
##       own STORE-07 wording: "LIFO returning a different crate of the same
##       kind is correct").
##   14. A Medium round trip. crate_13 (light textiles) racks into an empty
##       cell; both peers see occupancy 1 -- not eight Small slots -- and the
##       host proves the cell then refuses a Small (crate_11) outright, on
##       the host's own authoritative truth, the same idiom step 4 already
##       established. Retrieved; both peers see the cell empty and its
##       visual gone.
##   15. Heavy retrieval. crate_14 (masonry, 68 kg -- over
##       Crate.SOLO_CARRY_MASS_LIMIT) racks into a floor-level cell (a lone
##       dragger cannot reach any higher, ADR 19) and is retrieved solo. The
##       host's mass rule decides DRAG without being asked (ADR 19), the
##       crate comes to rest near the deck rather than rising to the
##       holder's eyeline, and the rack it came from does not shed itself
##       (MINT_GRACE_MS, re-checked against a body nearly six times a
##       Small's own mass).
##   16. A late joiner sees CONTENTS, not just counts. rack_island's cell 6
##       still holds crate_9's own dodgy Small record from step 12,
##       untouched since -- the exact broadcast a genuine late joiner would
##       receive (_rack_snapshot) is invoked directly, addressed at the
##       client, and the client asserts the resulting record's own category
##       and size, not merely that the cell shows something.

## Floor-level (depth=1, level=0 -- the same aimable side CELL_A/CELL_B/
## CELL_TOP_A/CELL_TOP_B already established), untouched by every step above
## this point: index 2 is the one cell on this rack nothing above this point
## ever names. Used for the Small round trip (step 13, a Small never comes
## close to a deck above it) and the heavy retrieval (step 15, ADR 19 means a
## dragged crate can never reach anywhere else anyway).
const CELL_ROUNDTRIP := 2

## CELL_A (7), reused rather than a fresh index -- long empty again by this
## point (steps 1/2/6 finished with it) -- and deliberately NOT a floor-level
## cell like CELL_ROUNDTRIP above. A retrieved crate under Crate.SOLO_CARRY_MASS_LIMIT
## is granted an ordinary CARRY, which lifts it toward the HOLDER's own eye
## height (~1.6-1.7 m world-absolute, independent of which cell it came
## from) -- and rack.tscn's own DeckMid/DeckTop shelves are real, solid
## CSGBox3D geometry at world y=1 and y=2 (each cell's nominal 1.0 m of
## height is actually ~0.95 m clear once a 0.05 m deck is subtracted).
## Retrieving a Medium (1.0 m) from CELL_ROUNDTRIP's own floor level once
## wedged it directly against DeckMid from below: the carry spring pulled
## it up, the deck blocked it from above, and the two forces reached a
## dead stop within centimetres of the deck's own underside -- found live,
## not reasoned about in advance (a diagnostic loop watching its own
## position for 2000+ frames measured a drift of 0.0024 m; that is a body
## pinned in a contact deadlock, not one merely moving slowly). CELL_A's
## own level (1) sits with clear air both above (up to DeckTop, y=2) and at
## the eye-height range a carry actually targets, so nothing above it can
## trap a Medium being lifted out.
const CELL_MEDIUM := 7

## crate_10..crate_14 are starting crates nothing above this point ever
## claims by name (see the 02-04/02-05 blocks in .planning/STATE.md for
## NAMED_ROW_CATEGORIES / HEAVY_ROW_ENTRIES) -- reserved for exactly this.
const CRATE_ROUNDTRIP_NAME := "crate_10"    ## glassware Small (fragility 3), named row index 10.
const CRATE_MEDIUM_NAME := "crate_13"       ## textiles Medium, 17 kg -- heavy row's light half.
const CRATE_MEDIUM_BLOCK_NAME := "crate_11" ## electronics Small -- the refused-Small probe for step 14.
const CRATE_HEAVY_MEDIUM_NAME := "crate_14" ## masonry Medium, 68 kg -- over SOLO_CARRY_MASS_LIMIT.

## Phase 3's own scuff input, mutated directly rather than produced by real
## dragging -- nothing in this game wires the two together yet
## (RigidBody-side Crate.drag_distance, the live physics accumulator, and
## CargoRecord.drag_distance, the wire field this test mutates, are still two
## separate things; connecting them is Phase 3's job). Any nonzero value
## proves the point -- that this field is not simply always zero by
## construction.
const ROUNDTRIP_DRAG_DISTANCE := 3.75

## How long CELL_ROUNDTRIP is left racked before step 13 retrieves it again.
## This is the ONE point in the whole file where a crate is racked and then
## immediately retrieved from the exact SAME cell with no walk to a
## different position and no second grab in between -- every other step's
## own natural walk-and-grab pacing already buys the client's polling loop
## real wall-clock time to land its own check in; this one constant buys it
## back for the step that does not have that for free.
const RECORD_CHECK_CONFIRM_MS := 500

## How close a retrieved heavy crate's own Y must land to the cell's deck
## height (step 15) to count as "rested," not "lifted to eye level."
## StorageGrid.mint_offset never touches Y (ADR 24's clearance shift is
## horizontal only), so the plain cell centre already IS the mint height; a
## carry would put the crate a good metre-plus higher, at the holder's own
## eyeline, so this tolerance only has to be wide enough for ordinary
## drag-spring settling, not for telling drag and carry apart.
const HEAVY_RETRIEVE_Y_TOLERANCE := 0.2

## Four distinct release spots for steps 13-15, all close to PARK_POINT
## rather than scattered further across the room. Two things had to both be
## true and, the first time this was written, were not:
##
## 1. Four releases landing at the exact SAME point in quick succession (as
##    these do -- the original steps 1-9 never dropped this often this close
##    together) settle (ADR 17) into real static geometry inside half a
##    second, and whatever walks toward that same spot next wedges against
##    it -- so each release needs its OWN spot.
## 2. A CARRIED crate's hold has its own break_distance (2.2 m, Crate.gd) --
##    [method _walk_to] TELEPORTS the player toward the target rather than
##    simulating a walk, and while that is fine at PARK_POINT's own short
##    ~3.5-4.5 m distance from the rack's approach corridor (proven safe by
##    every earlier step's own release), a park point far enough away (this
##    plan's own first attempt tried ~9 m, diagonally, in a direction that
##    does not match the walk) silently breaks the carry mid-transit --
##    [method Crate._break_hold] prints nothing, so this reads as a normal,
##    successful release right up until the STRANDED crate is later found
##    sitting in the middle of a completely different aim ray. Found live by
##    this plan's own suite hanging on a placement that should have been
##    routine, not by reasoning about it in advance.
##
## An intermediate attempt (all four ~2-4.5 m out, matching PARK_POINT's own
## rough distance) still broke one specific release ~4.65 m out while two
## shorter ones (1.9 m, 3.27 m) held — diagnosed with a temporary print in
## Crate._break_hold (never committed) that caught the exact moment and
## position: the hold broke less than a metre into the walk, stranding the
## crate right beside the rack, where it silently hijacked a later aim ray
## at an ADJACENT cell. Rather than chase the exact safe radius for this
## carry's own stiffness/mass, all four now sit within about 1.5-2 m of
## SOME approach point on this rack, closer than PARK_POINT itself, and
## spaced apart from each other by 1+ m so none sits in another's way.
const ROUNDTRIP_PARK_A := Vector3(6.0, STAND_HEIGHT, -6.5)
const ROUNDTRIP_PARK_B := Vector3(6.7, STAND_HEIGHT, -5.3)
const ROUNDTRIP_PARK_C := Vector3(8.4, STAND_HEIGHT, -5.0)
const ROUNDTRIP_PARK_D := Vector3(9.0, STAND_HEIGHT, -6.5)

## --- 02-08: a Large takes two cells, and the player picks which two
## (steps 17-21). ---
##
##   17. Side-by-side. The host drags crate_15 (machine_parts, 108 kg — every
##       Large exceeds SOLO_CARRY_MASS_LIMIT, ADR 25 (c), so a lone player
##       always drags one, never carries) into rack_island's own floor-level
##       SIDE_BY_SIDE pair (cells 2/3), aiming at cell 2 — SIDE_BY_SIDE is the
##       carrier's own default orientation on a fresh grant, so no rotate
##       press is needed for this half. Both peers assert: both cells
##       occupied, the same crate id on each half, exactly one racked visual,
##       the loose-crate count down by one.
##   18. Front-to-back, into the wall rack's dead row — the headline. The
##       host drags crate_16 (white_goods, 96 kg), presses rotate_placement
##       once, and aims at rack_wall's cell 3 (aimable, depth=1, floor
##       level). FRONT_TO_BACK lands its partner in cell 1 — depth=0, the row
##       01-04 found permanently unaimable and ADR 24 ratified as a
##       level-design property, reachable now only by arithmetic, with no
##       change to Carrier._aim() at all (ADR 25 (d)'s own central claim).
##       Both peers assert cell 1 is occupied, AND that the STORED
##       orientation itself reads FRONT_TO_BACK — the exact fact a
##       regression back to a hard-coded SIDE_BY_SIDE default would get
##       wrong while the occupancy check alone would not catch.
##   19. Retrieval hands back one crate. The host retrieves step 17's Large
##       by aiming at its PARTNER cell (3), not its anchor (2) — proving
##       either half resolves, not just the one that was aimed at to place
##       it. Both peers assert: both cells 2 and 3 empty, the racked visual
##       gone, the loose-crate count up by exactly one, the new body is a
##       fresh mint (a different id from the one that was racked — STORE-07's
##       own allowance), and every OTHER field matches the record captured
##       before it was ever racked. No mutation-and-replay trick is needed
##       here the way step 13's crate_round needed one: every crate in the
##       starting batch — Larges included — replicates an IDENTICAL record to
##       both peers at world load (Crate.setup()'s own "zero-cost
##       static-data channel"), so each peer captures its own baseline
##       independently, before either one ever touches it.
##   20. The dragged Large is refused above the floor. Still holding what
##       step 19 just handed back (a retrieval always re-grants a hold, and
##       ADR 19's mass rule decides DRAG unasked for anything this heavy —
##       every Large, always), the host aims at a non-floor cell on the same
##       rack (CELL_A, reused — see its own doc comment for why level, not
##       occupancy, is what ADR 19 checks) and is refused: still held, the
##       cell untouched. Then aims back at the SAME floor pair (2/3, empty
##       again since step 19) and succeeds. Roadmap success criterion 2,
##       proven for a Large specifically, not only for a Small or Medium.
##   21. A Large sheds as one crate. rack_wall's own top row is freed first —
##       crate_11, the step-15 sentinel, retrieved out through the real path
##       — and a synthetic Large record fills its untouched, permanently
##       unaimable depth=0 pair (cells 8/9) directly over the same
##       _cell_filled broadcast step 3's synthetic filler already used (this
##       is setup, not the thing under test; aimability is irrelevant to a
##       direct RPC fill). occupied_cells_in_top_row() returns a Large's
##       ANCHOR only (Rack's own rule, 02-05) — this is the exact case that
##       would double-mint the same Large if that rule ever regressed. A real
##       crate launched at the rack (the same impact this file already
##       proved sheds a row in step 8) triggers it: both peers assert exactly
##       ONE new body appeared and BOTH cells emptied.

const CRATE_LARGE_SIDE_NAME := "crate_15"   ## machine_parts LARGE, 108 kg.
const CRATE_LARGE_FRONT_NAME := "crate_16"  ## white_goods LARGE, 96 kg.

## Staged close to their own target rack before the first grab, the same
## direct-manipulation precedent this file already relies on for a LOOSE
## crate (see _ensure_awake's own doc comment) — both Larges start in the
## heavy row (test_room.gd, z=7.0), and dragging one the length of the room
## would cross the crate rows, the floor-stack cluster and both zones for no
## reason this plan needs. LARGE_STAGE_ISLAND shares GATE_PARK_POINT's own
## x/z (vetted clear in that constant's own doc comment); LARGE_STAGE_WALL
## sits a couple of metres from the ROUNDTRIP_PARK cluster, equally clear.
const LARGE_STAGE_ISLAND := Vector3(9.5, 0.5, 2.5)
const LARGE_STAGE_WALL := Vector3(7.5, 0.5, -6.9)

## rack_island's own floor-level SIDE_BY_SIDE pair — both depth=1, the
## aimable side every cell constant in this file already stands on.
## Untouched by every step above this point.
const CELL_LARGE_SIDE_ANCHOR := 2
const CELL_LARGE_SIDE_PARTNER := 3

## rack_wall's own floor-level FRONT_TO_BACK pair — 3 is depth=1 (aimable),
## its partner 1 is depth=0, the permanently-buried row 01-04 found and ADR 24
## ratified. Untouched by every step above this point.
const CELL_LARGE_FRONT_ANCHOR := 3
const CELL_LARGE_FRONT_PARTNER := 1

## rack_wall's own untouched, permanently unaimable depth=0 TOP row — 8/9 sit
## opposite the aimable 10/11 this file has used since step 7. A synthetic
## fill does not need aimability, only a genuinely free pair to land in.
const CELL_SHED_LARGE_ANCHOR := 8
const CELL_SHED_LARGE_PARTNER := 9

## The shed test's own synthetic record — the same category CarryAuthority
## would actually mint (machine_parts has a real LARGE row, cargo_catalogue.gd),
## a fresh id well clear of every real starting-batch crate and the step 3
## filler range (9000-9007).
const SHED_LARGE_ID := 9100

var _role := "host"
var _world: Node = null
var _steps_passed := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			_role = arg.trim_prefix("--role=")

	print("[test] role=%s port=%d" % [_role, TEST_PORT])

	Net.session_started.connect(_on_session_started)
	Net.session_failed.connect(_on_session_failed)

	if _role == "host":
		Net.local_player_name = "HOST"
		Net.host_session(Net.TransportKind.ENET, TEST_PORT)
	else:
		Net.local_player_name = "CLIENT"
		Net.join_session(Net.TransportKind.ENET, "127.0.0.1", TEST_PORT)

	_run()


func _on_session_started(as_host: bool) -> void:
	if _world != null:
		return
	_world = WORLD_SCENE.instantiate()
	add_child(_world)
	if as_host:
		print("[test] READY-TO-ACCEPT")


func _on_session_failed(reason: String) -> void:
	_fail("session", reason)
	_finish(false)


func _run() -> void:
	if not await _until("session up", func() -> bool: return Net.in_session()):
		return _finish(false)
	if not await _until("world loaded", func() -> bool: return _world != null):
		return _finish(false)
	if not await _until("both peers in roster", func() -> bool:
			return Net.players.size() == EXPECTED_PLAYERS):
		return _finish(false)
	if not await _until("all %d crates replicated" % EXPECTED_CRATES, func() -> bool:
			return _crates() != null and _crates().get_child_count() == EXPECTED_CRATES):
		return _finish(false)
	if not await _until("own body spawned", func() -> bool: return _me() != null):
		return _finish(false)

	var rack := _rack()
	if rack == null:
		_fail("find %s" % RACK_PATH, "not present under the world")
		return _finish(false)
	var rack2 := _rack_island()
	if rack2 == null:
		_fail("find %s" % RACK2_PATH, "not present under the world")
		return _finish(false)

	if _role == "host":
		await _run_host(rack, rack2)
	else:
		await _run_client(rack, rack2)


# --------------------------------------------------------------- host role

func _run_host(rack: Rack, rack2: Rack) -> void:
	# --- 1: host racks crate_0 into CELL_A. ---
	var crate_host := _crate_named(CRATE_HOST_NAME)
	if crate_host == null:
		_fail("find %s" % CRATE_HOST_NAME, "not present under Crates")
		return _finish(false)

	await _grab(crate_host)
	if not await _until("host holds %s" % CRATE_HOST_NAME, func() -> bool:
			return crate_host.holder_count() == 1):
		return _finish(false)
	# Captured now, not read off crate_host later: placing it frees the body
	# (ADR 14), and crate_host itself becomes a freed reference the instant
	# that happens. crate.id survives; the node does not.
	var crate_host_id := crate_host.id

	await _place(rack, CELL_A, HOST_LATERAL)
	if not await _until("crate_0 racked into cell %d" % CELL_A, func() -> bool:
			return rack.occupant(CELL_A) != -1):
		return _finish(false)
	# queue_free() defers the actual removal rather than doing it inline, so
	# polled rather than checked once — a check landing in the gap between
	# "the cell shows it" and "the node is actually gone" would read as a
	# real failure for a race that was never one.
	if not await _until("the body left the world on the host too", func() -> bool:
			return _crates().get_child_count() == EXPECTED_CRATES - 1):
		return _finish(false)
	_expect_now(
		rack.get_node_or_null("RackedItems/Cell%d_Item0" % CELL_A) != null,
		"cell %d shows its racked visual on the host" % CELL_A,
	)
	if not await _wait_for_settle(rack, CELL_A, 0):
		return _finish(false)

	# --- 2: client racks crate_1 into the same cell. Wait, then check back. ---
	if not await _until("client racked a second crate into cell %d" % CELL_A, func() -> bool:
			return rack.occupied_count(CELL_A) == 2):
		return _finish(false)
	if not await _until("both bodies left the world", func() -> bool:
			return _crates().get_child_count() == EXPECTED_CRATES - 2):
		return _finish(false)
	# The client's own placement, landing on the host's copy — proves the
	# tween converges for a non-host-initiated placement too, not just the
	# host's own.
	if not await _wait_for_settle(rack, CELL_A, 1):
		return _finish(false)
	# Captured now, while cell A's stack is known to hold exactly these two
	# and nothing else touches it before step 6 -- this is the id the LIFO
	# check at the end proves comes back out first, without this script
	# needing its own reference to whatever crate the client happened to grab.
	var crate_client_id := rack.occupant(CELL_A)

	# --- 3: fill CELL_B to capacity through the referee's own broadcast. ---
	# This is setup, not the thing under test, so it skips eight real
	# grab-and-place round trips — but it goes out over the same _cell_filled
	# RPC a real placement uses, so the client's own copy is genuinely full,
	# not merely asserted so on the host's say-so.
	var authority := _authority()
	if authority == null:
		_fail("find CarryAuthority", "not present under the world")
		return _finish(false)
	var before_budget := _crates().get_child_count()
	for i in FILLER_COUNT:
		# A real record, not a bare id/kind pair -- _cell_filled (02-06) carries
		# a whole CargoRecord dictionary now, and Rack.apply_cell_filled expects
		# one regardless of whether the caller is a genuine placement or this
		# scenario's own synthetic setup step.
		var filler_record := CargoCatalogue.mint(
			FILLER_KIND, FILLER_KIND, CargoCatalogue.Size.SMALL,
			FILLER_STORE_UNTIL_DAY, FILLER_OWNER, FILLER_CONTRACT_DAYS,
			FILLER_ID_START + i,
		).to_dict()
		authority._cell_filled.rpc(
			rack.name, CELL_B, filler_record, rack.cell_to_global_position(CELL_B),
			StorageGrid.Orientation.SIDE_BY_SIDE,
		)
	_expect_now(
		rack.occupied_count(CELL_B) == FILLER_COUNT,
		"cell %d holds all %d synthetic fillers on the host" % [CELL_B, FILLER_COUNT],
	)
	# The budget line: eight items now stored, at the cost of zero rigid
	# bodies -- Crates.get_child_count() has not moved, because none of these
	# were ever real crates in the first place. Printed as a [test] line so a
	# human reading the log sees the number, because it is the criterion most
	# likely to regress invisibly.
	print("[test]      budget: %d crates in the world, %d items in cell %d" % [
		_crates().get_child_count(), rack.occupied_count(CELL_B), CELL_B,
	])
	_expect_now(
		_crates().get_child_count() == before_budget,
		"storing 8 items spent zero bodies (%d before, %d after)" % [before_budget, _crates().get_child_count()],
	)
	# Unlike the placements above, nothing here ever calls queue_free() -- the
	# fillers were never real crate bodies -- so this one is safe to check
	# immediately rather than poll for.

	# --- 4: wait for the client to grab the full-cell attempt crate, and
	# confirm the refusal from the host's own authoritative truth, not the
	# client's say-so. A tight window starting right at the grab, because the
	# client releases this crate once its own check passes and moves on. ---
	var crate_full_attempt := _crate_named(CRATE_FULL_ATTEMPT_NAME)
	if crate_full_attempt == null:
		_fail("find %s" % CRATE_FULL_ATTEMPT_NAME, "not present under Crates")
		return _finish(false)
	if not await _until("client grabbed %s" % CRATE_FULL_ATTEMPT_NAME, func() -> bool:
			return crate_full_attempt.holder_count() == 1):
		return _finish(false)
	if not await _stays(
			"refused on the host's own truth: %s stays held, cell %d stays full" % [CRATE_FULL_ATTEMPT_NAME, CELL_B],
			func() -> bool:
				return (crate_full_attempt.holder_count() == 1
						and rack.occupied_count(CELL_B) == FILLER_COUNT)):
		return _finish(false)

	# --- 5: same shape, for the drag attempt against cell A (ADR 19). ---
	var crate_drag_attempt := _crate_named(CRATE_DRAG_ATTEMPT_NAME)
	if crate_drag_attempt == null:
		_fail("find %s" % CRATE_DRAG_ATTEMPT_NAME, "not present under Crates")
		return _finish(false)
	if not await _until("client is dragging %s" % CRATE_DRAG_ATTEMPT_NAME, func() -> bool:
			return (crate_drag_attempt.holder_count() == 1
					and crate_drag_attempt.hold_mode() == Crate.HoldMode.DRAG)):
		return _finish(false)
	if not await _stays(
			"ADR 19 on the host's own truth: %s stays dragged, cell %d untouched" % [CRATE_DRAG_ATTEMPT_NAME, CELL_A],
			func() -> bool:
				return (crate_drag_attempt.holder_count() == 1
						and crate_drag_attempt.hold_mode() == Crate.HoldMode.DRAG
						and rack.occupied_count(CELL_A) == 2)):
		return _finish(false)

	# The host's own stays window above is not proof the client's matching
	# window (which starts later -- the client still has to walk and press
	# three times first) has finished too. Without this, step 6 emptying
	# CELL_A can race the client's own read of occupied_count(CELL_A) == 2
	# mid-check -- exactly what happened before this wait was added. The
	# client drops crate_3 once its own check passes, so that release is the
	# signal step 6 is safe to start.
	if not await _until("client finished with %s" % CRATE_DRAG_ATTEMPT_NAME, func() -> bool:
			return crate_drag_attempt.holder_count() == 0):
		return _finish(false)

	# --- 6: retrieve twice from CELL_A with empty hands between each. ---
	#
	# LIFO is proven through the rack's own bookkeeping (rack.occupant()),
	# not through the id of whatever crate ends up in the retriever's hands:
	# request_retrieve always mints a brand new Crate body -- the one that
	# was placed was freed outright (ADR 14), nothing kept it in reserve --
	# so the physical crate that comes back has a fresh id unrelated to
	# which stored id was actually popped.
	_expect_now(
		rack.occupant(CELL_A) == crate_client_id,
		"LIFO: the most recently placed id (%d) is on top before the first retrieve (got %d)" % [crate_client_id, rack.occupant(CELL_A)],
	)
	var first := await _retrieve(rack, CELL_A, HOST_LATERAL)
	if first == null:
		_fail("first retrieve from cell %d" % CELL_A, "never granted")
		return _finish(false)
	_expect_now(
		rack.occupant(CELL_A) == crate_host_id,
		"LIFO: the first-placed id (%d) is what's left after popping the top one (got %d)" % [crate_host_id, rack.occupant(CELL_A)],
	)
	await _release_held()

	var second := await _retrieve(rack, CELL_A, HOST_LATERAL)
	if second == null:
		_fail("second retrieve from cell %d" % CELL_A, "never granted")
		return _finish(false)

	_expect_now(rack.is_cell_empty(CELL_A), "cell %d is empty after both retrievals" % CELL_A)
	# get_node_or_null() still finds a queue_free()'d node until the deferred
	# removal actually runs, same as Crates.get_child_count() above -- polled
	# for the same reason.
	if not await _until("cell %d's racked visual is gone" % CELL_A, func() -> bool:
			return rack.get_node_or_null("RackedItems/Cell%d_Item0" % CELL_A) == null):
		return _finish(false)
	if not await _until("every original crate id is a body again", func() -> bool:
			return _crates().get_child_count() == EXPECTED_CRATES):
		return _finish(false)

	# --- 7: fill two top-row cells for the shed test (01-07). ---
	#
	# The host is still holding what the second retrieve above handed back --
	# nothing in step 6 lets it go. Release it first, same empty-hands start
	# as every other grab in this file.
	await _release_held()

	var crate_shed_a := _crate_named(CRATE_SHED_A_NAME)
	if crate_shed_a == null:
		_fail("find %s" % CRATE_SHED_A_NAME, "not present under Crates")
		return _finish(false)
	await _grab(crate_shed_a)
	if not await _until("host holds %s" % CRATE_SHED_A_NAME, func() -> bool:
			return crate_shed_a.holder_count() == 1):
		return _finish(false)
	await _place(rack, CELL_TOP_A, HOST_LATERAL)
	if not await _until("%s racked into cell %d" % [CRATE_SHED_A_NAME, CELL_TOP_A], func() -> bool:
			return rack.occupant(CELL_TOP_A) != -1):
		return _finish(false)
	if not await _wait_for_settle(rack, CELL_TOP_A, 0):
		return _finish(false)

	var crate_shed_b := _crate_named(CRATE_SHED_B_NAME)
	if crate_shed_b == null:
		_fail("find %s" % CRATE_SHED_B_NAME, "not present under Crates")
		return _finish(false)
	await _grab(crate_shed_b)
	if not await _until("host holds %s" % CRATE_SHED_B_NAME, func() -> bool:
			return crate_shed_b.holder_count() == 1):
		return _finish(false)
	await _place(rack, CELL_TOP_B, HOST_LATERAL)
	if not await _until("%s racked into cell %d" % [CRATE_SHED_B_NAME, CELL_TOP_B], func() -> bool:
			return rack.occupant(CELL_TOP_B) != -1):
		return _finish(false)
	if not await _wait_for_settle(rack, CELL_TOP_B, 0):
		return _finish(false)

	# Baselines the shed's own assertions are measured against, recorded now
	# rather than as a literal constant -- everything above this point has
	# already shifted the loose-crate count more than once, so only a delta
	# from here is meaningful (see the file's own note on why).
	var crates_before_shed := _crates().get_child_count()
	var cell_b_before_shed := rack.occupied_count(CELL_B)

	# --- 8: launch a crate at the rack hard enough to shed it. ---
	#
	# Direct property manipulation, not a grab -- the same determinism trick
	# carry_session.gd's own _take() documents: a crate is always simulated
	# for real on the host, so setting its transform and velocity by hand is
	# a legitimate host action, not a workaround for one. crate_2 is loose
	# and unheld -- the client released it after its own refused-placement
	# check back in step 4.
	var impactor := _crate_named(CRATE_FULL_ATTEMPT_NAME)
	if impactor == null:
		_fail("find %s" % CRATE_FULL_ATTEMPT_NAME, "not present under Crates")
		return _finish(false)
	_ensure_awake(impactor)
	impactor.global_position = (rack.global_position
			+ rack.global_transform.basis.x * IMPACT_LATERAL_OFFSET
			+ rack.global_transform.basis.z * IMPACT_START_OFFSET_Z
			+ Vector3.UP * IMPACT_HEIGHT)
	impactor.sleeping = false
	impactor.linear_velocity = -rack.global_transform.basis.z * IMPACT_SPEED
	impactor.angular_velocity = Vector3.ZERO

	if not await _until("the impact sheds cell %d" % CELL_TOP_A, func() -> bool:
			return rack.occupied_count(CELL_TOP_A) == 0):
		return _finish(false)
	if not await _until("the impact sheds cell %d" % CELL_TOP_B, func() -> bool:
			return rack.occupied_count(CELL_TOP_B) == 0):
		return _finish(false)
	_expect_now(
		rack.occupied_count(CELL_B) == cell_b_before_shed,
		"the bound holds: cell %d (not top row) is untouched by the shed" % CELL_B,
	)
	if not await _until("the shed spent exactly two new bodies", func() -> bool:
			return _crates().get_child_count() == crates_before_shed + 2):
		return _finish(false)
	if not await _until("cell %d's racked visual is gone after the shed" % CELL_TOP_A, func() -> bool:
			return rack.get_node_or_null("RackedItems/Cell%d_Item0" % CELL_TOP_A) == null):
		return _finish(false)
	if not await _until("cell %d's racked visual is gone after the shed" % CELL_TOP_B, func() -> bool:
			return rack.get_node_or_null("RackedItems/Cell%d_Item0" % CELL_TOP_B) == null):
		return _finish(false)

	# --- 9: floor stacking still works (success criterion 5, first half). ---
	#
	# Same direct-manipulation trick as the impactor above. crate_2 (the
	# impactor, now loose wherever the shed's own impulse and gravity left
	# it) and crate_3 (loose since step 5) are both unheld and otherwise
	# unused for the rest of this scenario.
	var stack_bottom := impactor
	var stack_top := _crate_named(CRATE_DRAG_ATTEMPT_NAME)
	if stack_top == null:
		_fail("find %s" % CRATE_DRAG_ATTEMPT_NAME, "not present under Crates")
		return _finish(false)
	_ensure_awake(stack_bottom)
	stack_bottom.global_position = STACK_BASE
	stack_bottom.sleeping = false
	stack_bottom.linear_velocity = Vector3.ZERO
	stack_bottom.angular_velocity = Vector3.ZERO
	_ensure_awake(stack_top)
	stack_top.global_position = STACK_BASE + Vector3.UP * STACK_DROP_HEIGHT
	stack_top.sleeping = false
	stack_top.linear_velocity = Vector3.ZERO
	stack_top.angular_velocity = Vector3.ZERO

	if not await _until("the stacked crate rests on top rather than sinking through", func() -> bool:
			return stack_top.global_position.y > STACK_SETTLED_MIN_Y):
		return _finish(false)

	# --- 10: regression - retrieval directly beside a loaded top row does
	# NOT shed. See the "Wave 7 gate regressions" block comment below
	# STACK_SETTLED_MIN_Y for the full reasoning; rack2 (rack_island) is
	# untouched by everything above. ---
	var crate_gate_a := _crate_named(CRATE_GATE_TOP_A_NAME)
	if crate_gate_a == null:
		_fail("find %s" % CRATE_GATE_TOP_A_NAME, "not present under Crates")
		return _finish(false)
	await _grab(crate_gate_a)
	if not await _until("host holds %s" % CRATE_GATE_TOP_A_NAME, func() -> bool:
			return crate_gate_a.holder_count() == 1):
		return _finish(false)
	# avoid_rack_island=true: see RACK_ISLAND_CORNER_WAYPOINT's own doc
	# comment — a direct walk from the row crosses this rack's own footprint.
	# Not load-bearing for crate_6 itself (the rack is still empty, so
	# Rack._on_impact's own is_empty() guard would absorb any spurious
	# impact here regardless), but the waypoint costs almost nothing over the
	# direct path, so this stays consistent with crate_7's own approach below
	# rather than leaving a latent version of the same hazard for whichever
	# crate goes into this cell if the step order ever changes.
	await _place(rack2, CELL_TOP_A, HOST_LATERAL, RACK_STAND_OFFSET_Z, true)
	if not await _until("%s racked into rack_island cell %d" % [CRATE_GATE_TOP_A_NAME, CELL_TOP_A], func() -> bool:
			return rack2.occupant(CELL_TOP_A) != -1):
		return _finish(false)
	if not await _wait_for_settle(rack2, CELL_TOP_A, 0):
		return _finish(false)

	var crate_gate_b := _crate_named(CRATE_GATE_TOP_B_NAME)
	if crate_gate_b == null:
		_fail("find %s" % CRATE_GATE_TOP_B_NAME, "not present under Crates")
		return _finish(false)
	await _grab(crate_gate_b)
	if not await _until("host holds %s" % CRATE_GATE_TOP_B_NAME, func() -> bool:
			return crate_gate_b.holder_count() == 1):
		return _finish(false)
	# avoid_rack_island=true: see RACK_ISLAND_CORNER_WAYPOINT's own doc
	# comment. Load-bearing here specifically — this is the placement whose
	# direct walk sheds cell 10 out from under crate_7's own approach.
	await _place(rack2, CELL_TOP_B, HOST_LATERAL, RACK_STAND_OFFSET_Z, true)
	if not await _until("%s racked into rack_island cell %d" % [CRATE_GATE_TOP_B_NAME, CELL_TOP_B], func() -> bool:
			return rack2.occupant(CELL_TOP_B) != -1):
		return _finish(false)
	if not await _wait_for_settle(rack2, CELL_TOP_B, 0):
		return _finish(false)

	# Captured immediately before the retrieval that is actually under test --
	# everything above this point has already moved the loose-crate count more
	# than once, so only a delta from here is meaningful, same reasoning as
	# crates_before_shed in step 7-8 above.
	var crates_before_gate_retrieve := _crates().get_child_count()

	var gate_retrieved := await _retrieve(rack2, CELL_TOP_A, HOST_LATERAL)
	if gate_retrieved == null:
		_fail("retrieve from rack_island cell %d" % CELL_TOP_A, "never granted")
		return _finish(false)
	# Waited for, not checked in the same breath as the stays-window below:
	# _cell_cleared and the retrieval's own crate spawn are two separate
	# reliable messages with no ordering guarantee between them landing in
	# the same polled frame, the same class of race the queue_free() despawn
	# checks elsewhere in this file already account for. Folding this into
	# the stays-window's own predicate would fail it the instant the spawn
	# happened to lag the cell-clear by even one frame.
	if not await _until("the retrieval spent exactly one new body", func() -> bool:
			return _crates().get_child_count() == crates_before_gate_retrieve + 1):
		return _finish(false)
	if not await _stays(
			"regression: retrieving cell %d does not shed the still-loaded neighbour cell %d" % [CELL_TOP_A, CELL_TOP_B],
			func() -> bool:
				return (rack2.occupied_count(CELL_TOP_B) == 1
						and _crates().get_child_count() == crates_before_gate_retrieve + 1)):
		return _finish(false)
	await _release_held(GATE_PARK_POINT)

	# --- 11: regression - a crate stranded inside a rack's own CellSensor
	# volume is grabbable through the real interact path, not permanently
	# lost. ---
	var crate_stranded := _crate_named(CRATE_GATE_STRANDED_NAME)
	if crate_stranded == null:
		_fail("find %s" % CRATE_GATE_STRANDED_NAME, "not present under Crates")
		return _finish(false)
	_ensure_awake(crate_stranded)
	crate_stranded.global_position = rack2.cell_to_global_position(CELL_A)
	crate_stranded.linear_velocity = Vector3.ZERO
	crate_stranded.angular_velocity = Vector3.ZERO

	# Real gravity carries it down onto the rack's own deck rather than
	# leaving it floating at the cell's mathematical centre — waited for
	# rather than assumed, the same "state, not time" rule every other step
	# here follows. sync_settled (ADR 17) is the same signal a real shed
	# crate would eventually reach too.
	if not await _until("%s falls and settles inside cell %d's sensor volume" % [CRATE_GATE_STRANDED_NAME, CELL_A], func() -> bool:
			return crate_stranded.sync_settled):
		return _finish(false)

	# STRANDED_STAND_OFFSET_Z, not the default RACK_STAND_OFFSET_Z — this grab
	# checks against the crate's own settled (lower) position, not the cell's
	# mathematical centre, and needs its own closer stand point to still clear
	# GRAB_REACH. See that constant's own doc comment for the arithmetic.
	await _approach_cell(rack2, CELL_A, HOST_LATERAL, false, STRANDED_STAND_OFFSET_Z)
	var me := _me()
	var carrier: Carrier = me.get_node("Carrier")
	# Aimed at the crate's own resting position rather than the cell's
	# mathematical centre — gravity settled it onto the deck below, not
	# exactly at the centre a shed crate would rarely land on either.
	var aim_target := crate_stranded.global_position
	var deadline := Time.get_ticks_msec() + STEP_TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		if carrier.held_crate() == crate_stranded:
			break
		me.aim_at(aim_target)
		carrier.try_toggle_hold()
		for _i in 6:
			await get_tree().process_frame
	_expect_now(
		carrier.held_crate() == crate_stranded,
		"the stranded %s was grabbed through the real interact path, not left permanently unreachable" % CRATE_GATE_STRANDED_NAME,
	)

	# Held deliberately for a moment before releasing — see
	# GATE_HOLD_CONFIRM_MS's own doc comment. The client's own matching check
	# (in _run_client) is what actually proves this replicated; this is just
	# giving it the time to.
	var hold_confirm_deadline := Time.get_ticks_msec() + GATE_HOLD_CONFIRM_MS
	while Time.get_ticks_msec() < hold_confirm_deadline:
		await get_tree().process_frame
	await _release_held(GATE_PARK_POINT)

	# --- 12: regression - a genuine maximum-range aim succeeds. ---
	var crate_max_range := _crate_named(CRATE_GATE_MAX_RANGE_NAME)
	if crate_max_range == null:
		_fail("find %s" % CRATE_GATE_MAX_RANGE_NAME, "not present under Crates")
		return _finish(false)
	await _grab(crate_max_range)
	if not await _until("host holds %s" % CRATE_GATE_MAX_RANGE_NAME, func() -> bool:
			return crate_max_range.holder_count() == 1):
		return _finish(false)
	await _place(rack2, CELL_B, HOST_LATERAL, MAX_RANGE_STAND_OFFSET_Z)
	if not await _until("%s racked into rack_island cell %d from maximum range" % [CRATE_GATE_MAX_RANGE_NAME, CELL_B], func() -> bool:
			return rack2.occupant(CELL_B) != -1):
		return _finish(false)
	if not await _wait_for_settle(rack2, CELL_B, 0):
		return _finish(false)

	# --- 13: STORE-07, the round trip, field for field. ---
	var crate_round := _crate_named(CRATE_ROUNDTRIP_NAME)
	if crate_round == null:
		_fail("find %s" % CRATE_ROUNDTRIP_NAME, "not present under Crates")
		return _finish(false)

	await _grab(crate_round)
	if not await _until("host holds %s" % CRATE_ROUNDTRIP_NAME, func() -> bool:
			return crate_round.holder_count() == 1):
		return _finish(false)

	# Two fields Phase 3 will own, mutated directly (see ROUNDTRIP_DRAG_DISTANCE's
	# own doc comment): a nonzero drag_distance, and a condition patched so
	# actual and apparent genuinely diverge (GOODS-05) -- the single most
	# important thing not to lose on this trip.
	crate_round.record.drag_distance = ROUNDTRIP_DRAG_DISTANCE
	var round_condition := crate_round.record.condition()
	round_condition.worsen(2)
	round_condition.apply_tape()
	crate_round.record.set_condition(round_condition)

	# Captured HERE, after the mutation and before _place (-> request_place)
	# frees the body -- once that happens there is nothing left to ask.
	# Duplicated defensively even though every value is a primitive, matching
	# this project's own established discipline (occupancy_snapshot,
	# CargoRecord.duplicate_record) of never trusting a dictionary handed
	# elsewhere not to be mutated afterward.
	var captured_round_record: Dictionary = crate_round.record.to_dict().duplicate(true)

	await _place(rack, CELL_ROUNDTRIP, HOST_LATERAL)
	if not await _until("%s racked into cell %d" % [CRATE_ROUNDTRIP_NAME, CELL_ROUNDTRIP], func() -> bool:
			return rack.occupant(CELL_ROUNDTRIP) != -1):
		return _finish(false)
	if not await _wait_for_settle(rack, CELL_ROUNDTRIP, 0):
		return _finish(false)
	_expect_record_matches(
		"host: cell %d's own stored record matches the captured one" % CELL_ROUNDTRIP,
		captured_round_record, rack.occupant_record(CELL_ROUNDTRIP),
	)

	# Held open deliberately -- see RECORD_CHECK_CONFIRM_MS's own doc comment.
	# This is the one racking in the whole file with nothing else happening
	# between placing and retrieving the SAME cell, so the client's own
	# field-by-field check (_run_client) needs this window bought back for it.
	var record_check_deadline := Time.get_ticks_msec() + RECORD_CHECK_CONFIRM_MS
	while Time.get_ticks_msec() < record_check_deadline:
		await get_tree().process_frame

	var round_retrieved := await _retrieve(rack, CELL_ROUNDTRIP, HOST_LATERAL)
	if round_retrieved == null:
		_fail("retrieve %s from cell %d" % [CRATE_ROUNDTRIP_NAME, CELL_ROUNDTRIP], "never granted")
		return _finish(false)
	# id is excluded deliberately -- see _expect_record_matches' own doc
	# comment. Asserted explicitly here, once, rather than silently skipped,
	# so the divergence is a documented fact, not an absence.
	_expect_now(
		round_retrieved.id != int(captured_round_record["id"]),
		"host: the retrieved body is a NEW mint (id %d), not the same object that was racked (id %d) -- by design, not a bug" % [round_retrieved.id, int(captured_round_record["id"])],
	)
	_expect_record_matches(
		"host: retrieved record matches the captured one",
		captured_round_record, round_retrieved.record.to_dict(), true,
	)
	await _release_held(ROUNDTRIP_PARK_A)

	# --- 14: a Medium round trip. ---
	var crate_medium := _crate_named(CRATE_MEDIUM_NAME)
	if crate_medium == null:
		_fail("find %s" % CRATE_MEDIUM_NAME, "not present under Crates")
		return _finish(false)
	await _grab(crate_medium)
	if not await _until("host holds %s" % CRATE_MEDIUM_NAME, func() -> bool:
			return crate_medium.holder_count() == 1):
		return _finish(false)
	await _place(rack, CELL_MEDIUM, HOST_LATERAL)
	if not await _until("%s racked into cell %d" % [CRATE_MEDIUM_NAME, CELL_MEDIUM], func() -> bool:
			return rack.occupant(CELL_MEDIUM) != -1):
		return _finish(false)
	if not await _wait_for_settle(rack, CELL_MEDIUM, 0, CargoCatalogue.Size.MEDIUM):
		return _finish(false)
	_expect_now(
		rack.occupied_count(CELL_MEDIUM) == 1,
		"cell %d holds exactly one Medium, not eight Small slots (ADR 18)" % CELL_MEDIUM,
	)

	# The refusal probe: a Small can never enter a cell already holding a
	# Medium, whatever its category (StorageGrid.cell_can_accept refuses on
	# cell["size"] alone once occupied) -- crate_11 (electronics) is a
	# different category from crate_13 (textiles) on purpose, so this proves
	# the SIZE mismatch refuses it, not merely a category mismatch that would
	# have refused it anyway.
	var crate_medium_block := _crate_named(CRATE_MEDIUM_BLOCK_NAME)
	if crate_medium_block == null:
		_fail("find %s" % CRATE_MEDIUM_BLOCK_NAME, "not present under Crates")
		return _finish(false)
	await _grab(crate_medium_block)
	if not await _until("host holds %s" % CRATE_MEDIUM_BLOCK_NAME, func() -> bool:
			return crate_medium_block.holder_count() == 1):
		return _finish(false)
	await _attempt_place(rack, CELL_MEDIUM, HOST_LATERAL)
	if not await _stays(
			"ADR 18 on the host's own truth: a Small is refused by cell %d (already holding a Medium)" % CELL_MEDIUM,
			func() -> bool:
				return (crate_medium_block.holder_count() == 1
						and rack.occupied_count(CELL_MEDIUM) == 1)):
		return _finish(false)
	await _release_held(ROUNDTRIP_PARK_B)

	var medium_retrieved := await _retrieve(rack, CELL_MEDIUM, HOST_LATERAL)
	if medium_retrieved == null:
		_fail("retrieve %s from cell %d" % [CRATE_MEDIUM_NAME, CELL_MEDIUM], "never granted")
		return _finish(false)
	_expect_now(rack.is_cell_empty(CELL_MEDIUM), "cell %d is empty after the Medium is retrieved" % CELL_MEDIUM)
	if not await _until("cell %d's racked visual is gone" % CELL_MEDIUM, func() -> bool:
			return rack.get_node_or_null("RackedItems/Cell%d_Item0" % CELL_MEDIUM) == null):
		return _finish(false)
	# _teleport_release, not _release_held -- see that method's own doc
	# comment. A CARRIED Medium's own alignment torque (Crate._apply_carry_forces,
	# absent entirely from a drag -- see Crate._apply_drag_forces' own "no
	# alignment torque either" comment) can wedge it against this rack's own
	# corner upright while still exiting the cell it just came from, and
	# once wedged the spring cannot free it: measured waiting the FULL
	# catch-up ceiling (~21 s) with the crate barely moving. crate_heavy's
	# own retrieval two cells over, moments later, is unaffected because it
	# is DRAGGED, never carried (ADR 19's mass rule) -- this is specifically
	# a carried-Medium-exiting-a-rack-cell finding, not a general one.
	_teleport_release(ROUNDTRIP_PARK_C)

	# --- 15: heavy retrieval. ---
	#
	# First, a sentinel: crate_11 (already used once, in step 14's refusal
	# probe, and free again since) is racked back into cell CELL_TOP_A -- the
	# same top-row cell step 7/8 already proved sheddable -- so there is
	# something loaded to prove UNSHED when the heavy retrieval below happens.
	# Without this, cell CELL_TOP_A is simply empty at this point (step 8
	# already shed it), and "the rack it came from did not shed itself" would
	# read 0 == 0 whether or not MINT_GRACE_MS actually still works -- a
	# vacuous pass. crate_11 is solo-liftable (9 kg, electronics), so this is
	# an ordinary carried placement, no ADR 19 floor restriction involved.
	var crate_sentinel := _crate_named(CRATE_MEDIUM_BLOCK_NAME)
	if crate_sentinel == null:
		_fail("find %s" % CRATE_MEDIUM_BLOCK_NAME, "not present under Crates")
		return _finish(false)
	await _grab(crate_sentinel)
	if not await _until("host holds %s again (the sentinel)" % CRATE_MEDIUM_BLOCK_NAME, func() -> bool:
			return crate_sentinel.holder_count() == 1):
		return _finish(false)
	print("[DEBUG] TIMING checkpoint C (about to grab+place sentinel) at ms=%d" % Time.get_ticks_msec())
	await _place(rack, CELL_TOP_A, HOST_LATERAL)
	if not await _until("sentinel %s racked into cell %d" % [CRATE_MEDIUM_BLOCK_NAME, CELL_TOP_A], func() -> bool:
			return rack.occupant(CELL_TOP_A) != -1):
		return _finish(false)
	print("[DEBUG] TIMING checkpoint D (sentinel racked) at ms=%d" % Time.get_ticks_msec())
	if not await _wait_for_settle(rack, CELL_TOP_A, 0):
		return _finish(false)

	# crate_14 (masonry Medium, 68 kg) exceeds Crate.SOLO_CARRY_MASS_LIMIT
	# (30), so grabbing it solo resolves to HoldMode.DRAG regardless of which
	# button is pressed (ADR 19's mass rule) -- and a dragger's hold point
	# comes from the capsule's yaw, not the camera, so it can only ever reach
	# a floor-level cell. CELL_ROUNDTRIP is floor level and empty again since
	# step 13's own retrieval, so it is reused rather than a third cell added.
	var crate_heavy := _crate_named(CRATE_HEAVY_MEDIUM_NAME)
	if crate_heavy == null:
		_fail("find %s" % CRATE_HEAVY_MEDIUM_NAME, "not present under Crates")
		return _finish(false)
	await _grab(crate_heavy)
	if not await _until("host is dragging %s (ADR 19's mass rule, unasked)" % CRATE_HEAVY_MEDIUM_NAME, func() -> bool:
			return (crate_heavy.holder_count() == 1
					and crate_heavy.hold_mode() == Crate.HoldMode.DRAG)):
		return _finish(false)
	await _place(rack, CELL_ROUNDTRIP, HOST_LATERAL)
	if not await _until("%s racked into cell %d" % [CRATE_HEAVY_MEDIUM_NAME, CELL_ROUNDTRIP], func() -> bool:
			return rack.occupant(CELL_ROUNDTRIP) != -1):
		return _finish(false)
	if not await _wait_for_settle(rack, CELL_ROUNDTRIP, 0, CargoCatalogue.Size.MEDIUM):
		return _finish(false)

	# The deck height a heavy retrieval should come to rest near, not rise
	# away from -- the same cell centre mint_position offsets from (a Small
	# clears cleanly, ADR 24; a Medium's own mint_offset shift is horizontal
	# only, so the vertical reference is unchanged).
	var heavy_deck_y := rack.cell_to_global_position(CELL_ROUNDTRIP).y
	var heavy_neighbour_top_a_before := rack.occupied_count(CELL_TOP_A)

	var heavy_retrieved := await _retrieve(rack, CELL_ROUNDTRIP, HOST_LATERAL)
	if heavy_retrieved == null:
		_fail("retrieve %s from cell %d" % [CRATE_HEAVY_MEDIUM_NAME, CELL_ROUNDTRIP], "never granted")
		return _finish(false)
	_expect_now(
		heavy_retrieved.hold_mode() == Crate.HoldMode.DRAG,
		"heavy retrieval: the host's mass rule decided DRAG, not asked for -- got %s" % heavy_retrieved.hold_mode(),
	)
	_expect_now(
		absf(heavy_retrieved.global_position.y - heavy_deck_y) < HEAVY_RETRIEVE_Y_TOLERANCE,
		"heavy retrieval: %s rests near the deck (y=%.3f, deck y=%.3f) rather than rising to eye level" % [
			CRATE_HEAVY_MEDIUM_NAME, heavy_retrieved.global_position.y, heavy_deck_y,
		],
	)
	_expect_now(
		rack.occupied_count(CELL_TOP_A) == heavy_neighbour_top_a_before,
		"heavy retrieval: the rack it came from did not shed itself (cell %d unchanged)" % CELL_TOP_A,
	)
	await _release_held(ROUNDTRIP_PARK_D)

	# --- 16: a late joiner sees CONTENTS, not just counts. ---
	#
	# _on_player_ready_for_spawn only ever fires host-side for a THIRD peer
	# joining a rack that already holds something -- this scenario is
	# deliberately only ever two peers (test/README.md: "starting processes
	# is most of the runtime"), so the snapshot RPC that path would send is
	# invoked directly here, addressed at the client, exactly as a genuine
	# late join would trigger it. rack2 (rack_island) cell CELL_B still
	# holds crate_9's own dodgy Small record from step 12, untouched since.
	var snapshot_before := rack2.occupant_record(CELL_B)
	_expect_now(
		snapshot_before.get("category", &"") == &"dodgy" and int(snapshot_before.get("size", -1)) == CargoCatalogue.Size.SMALL,
		"host: rack_island cell %d still holds the dodgy Small before the snapshot is even sent" % CELL_B,
	)
	var client_peer_id := _client_peer_id()
	if client_peer_id != -1:
		# Godot 4's rpc_id has no "everyone but me" sentinel -- a negative id
		# is simply an unknown peer, and calling it that way is a real engine
		# ERROR (zero-tolerance), not a silent no-op the way it would have
		# been in Godot 3. -1 here would mean the client already disconnected
		# (e.g. it gave up on an earlier wait and quit) -- nothing left to
		# snapshot to, so skip rather than call something guaranteed to fail.
		authority._rack_snapshot.rpc_id(client_peer_id, rack2.name, rack2.occupancy_snapshot())

	# --- 17: a Large takes two cells, side by side. ---
	var crate_large_side := _crate_named(CRATE_LARGE_SIDE_NAME)
	if crate_large_side == null:
		_fail("find %s" % CRATE_LARGE_SIDE_NAME, "not present under Crates")
		return _finish(false)
	# Captured before anything moves it — the baseline step 19 compares
	# against once it comes back out. No mutation-and-replay trick needed
	# here (see this file's own note above _run_client's matching capture):
	# every starting-batch crate, Larges included, replicates an IDENTICAL
	# record to both peers at world load.
	var captured_large_side_record: Dictionary = crate_large_side.record.to_dict().duplicate(true)

	_ensure_awake(crate_large_side)
	crate_large_side.global_position = LARGE_STAGE_ISLAND
	crate_large_side.sleeping = false
	crate_large_side.linear_velocity = Vector3.ZERO
	crate_large_side.angular_velocity = Vector3.ZERO

	await _grab(crate_large_side, true)
	if not await _until("host is dragging %s (every Large exceeds the solo-lift limit, ADR 25 (c))" % CRATE_LARGE_SIDE_NAME, func() -> bool:
			return (crate_large_side.holder_count() == 1
					and crate_large_side.hold_mode() == Crate.HoldMode.DRAG)):
		return _finish(false)

	var crates_before_large_side := _crates().get_child_count()
	# SIDE_BY_SIDE is the carrier's own default on a fresh grant — no rotate
	# press needed for this half.
	await _place(rack2, CELL_LARGE_SIDE_ANCHOR, HOST_LATERAL)
	if not await _until("%s racked into rack_island cell %d, side by side" % [CRATE_LARGE_SIDE_NAME, CELL_LARGE_SIDE_ANCHOR], func() -> bool:
			return rack2.occupant(CELL_LARGE_SIDE_ANCHOR) != -1):
		return _finish(false)
	if not await _wait_for_settle(rack2, CELL_LARGE_SIDE_ANCHOR, 0, CargoCatalogue.Size.LARGE, CELL_LARGE_SIDE_PARTNER):
		return _finish(false)
	_expect_now(
		rack2.occupied_count(CELL_LARGE_SIDE_PARTNER) == 1,
		"the SIDE_BY_SIDE partner cell %d is occupied too, not just the anchor" % CELL_LARGE_SIDE_PARTNER,
	)
	_expect_now(
		rack2.occupant(CELL_LARGE_SIDE_ANCHOR) == rack2.occupant(CELL_LARGE_SIDE_PARTNER),
		"both halves report the SAME crate id -- one Large, not two",
	)
	if not await _until("the Large's body left the world (it frees on racking too)", func() -> bool:
			return _crates().get_child_count() == crates_before_large_side - 1):
		return _finish(false)

	# --- 18: front-to-back, into the wall rack's dead row -- the headline. ---
	var crate_large_front := _crate_named(CRATE_LARGE_FRONT_NAME)
	if crate_large_front == null:
		_fail("find %s" % CRATE_LARGE_FRONT_NAME, "not present under Crates")
		return _finish(false)
	_ensure_awake(crate_large_front)
	crate_large_front.global_position = LARGE_STAGE_WALL
	crate_large_front.sleeping = false
	crate_large_front.linear_velocity = Vector3.ZERO
	crate_large_front.angular_velocity = Vector3.ZERO

	await _grab(crate_large_front, true)
	if not await _until("host is dragging %s" % CRATE_LARGE_FRONT_NAME, func() -> bool:
			return (crate_large_front.holder_count() == 1
					and crate_large_front.hold_mode() == Crate.HoldMode.DRAG)):
		return _finish(false)

	var carrier_host: Carrier = _me().get_node("Carrier")
	carrier_host.rotate_placement()

	var crates_before_large_front := _crates().get_child_count()
	await _place(rack, CELL_LARGE_FRONT_ANCHOR, HOST_LATERAL)
	if not await _until("%s racked into rack_wall cell %d, front to back" % [CRATE_LARGE_FRONT_NAME, CELL_LARGE_FRONT_ANCHOR], func() -> bool:
			return rack.occupant(CELL_LARGE_FRONT_ANCHOR) != -1):
		return _finish(false)
	if not await _wait_for_settle(rack, CELL_LARGE_FRONT_ANCHOR, 0, CargoCatalogue.Size.LARGE, CELL_LARGE_FRONT_PARTNER):
		return _finish(false)
	# The headline assertion: cell 1 (depth=0) is now occupied, and no aim
	# ray anywhere in this file has ever been able to reach it directly.
	_expect_now(
		rack.occupied_count(CELL_LARGE_FRONT_PARTNER) == 1,
		"rack_wall's permanently unaimable cell %d is filled, by arithmetic, with no change to Carrier._aim() at all" % CELL_LARGE_FRONT_PARTNER,
	)
	_expect_now(
		rack.cell_orientation(CELL_LARGE_FRONT_ANCHOR) == StorageGrid.Orientation.FRONT_TO_BACK,
		"the STORED orientation itself reads FRONT_TO_BACK -- not a hard-coded SIDE_BY_SIDE default",
	)
	if not await _until("the Large's body left the world", func() -> bool:
			return _crates().get_child_count() == crates_before_large_front - 1):
		return _finish(false)

	# --- 19: retrieval hands back one crate, field for field. ---
	var crates_before_large_retrieve := _crates().get_child_count()
	# The PARTNER cell (3), not the anchor (2) -- proving either half resolves.
	var large_retrieved := await _retrieve(rack2, CELL_LARGE_SIDE_PARTNER, HOST_LATERAL)
	if large_retrieved == null:
		_fail("retrieve %s from rack_island cell %d" % [CRATE_LARGE_SIDE_NAME, CELL_LARGE_SIDE_PARTNER], "never granted")
		return _finish(false)
	_expect_now(
		rack2.is_cell_empty(CELL_LARGE_SIDE_ANCHOR) and rack2.is_cell_empty(CELL_LARGE_SIDE_PARTNER),
		"BOTH cells %d and %d are empty -- a rack never holds half a Large" % [CELL_LARGE_SIDE_ANCHOR, CELL_LARGE_SIDE_PARTNER],
	)
	if not await _until("rack_island's racked visual is gone after the retrieval", func() -> bool:
			return rack2.get_node_or_null("RackedItems/Cell%d_Item0" % CELL_LARGE_SIDE_ANCHOR) == null):
		return _finish(false)
	if not await _until("the retrieval spent exactly one new body, not two", func() -> bool:
			return _crates().get_child_count() == crates_before_large_retrieve + 1):
		return _finish(false)
	_expect_now(
		large_retrieved.id != int(captured_large_side_record["id"]),
		"host: the retrieved body is a NEW mint (id %d), not the same object that was racked (id %d) -- by design" % [large_retrieved.id, int(captured_large_side_record["id"])],
	)
	_expect_record_matches(
		"host: retrieved Large's record matches the one captured before it was ever racked",
		captured_large_side_record, large_retrieved.record.to_dict(), true,
	)
	# ADR 19's mass rule decided this unasked -- ties step 19 to step 20 below,
	# which needs the SAME held crate to still be a drag.
	_expect_now(
		large_retrieved.hold_mode() == Crate.HoldMode.DRAG,
		"the retrieved Large is a DRAG, not a CARRY -- ADR 19's mass rule, unasked",
	)

	# --- 20: the dragged Large is refused above the floor. ---
	#
	# CELL_A (7, level=1) reused deliberately -- ADR 19's refusal fires on
	# LEVEL alone (Carrier._placement_allowed / CarryAuthority.request_place),
	# before room is ever checked, so it does not matter that this exact cell
	# was last touched many steps ago and is now empty; the refusal would be
	# identical if it were full.
	await _attempt_place(rack2, CELL_A, HOST_LATERAL)
	if not await _stays(
			"ADR 19 on a Large: still dragging %s, cell %d untouched (roadmap success criterion 2)" % [CRATE_LARGE_SIDE_NAME, CELL_A],
			func() -> bool:
				return (large_retrieved.holder_count() == 1
						and large_retrieved.hold_mode() == Crate.HoldMode.DRAG
						and rack2.is_cell_empty(CELL_A))):
		return _finish(false)

	var crates_before_large_refloor := _crates().get_child_count()
	# Back at the SAME floor pair, empty again since step 19 -- the contrast
	# that makes the refusal above mean something rather than "nothing
	# happened". SIDE_BY_SIDE is still the carrier's own orientation (this
	# hold never rotated away from its fresh-grant default).
	await _place(rack2, CELL_LARGE_SIDE_ANCHOR, HOST_LATERAL)
	if not await _until("%s racked back into cell %d at floor level -- a lone dragger CAN reach it" % [CRATE_LARGE_SIDE_NAME, CELL_LARGE_SIDE_ANCHOR], func() -> bool:
			return rack2.occupant(CELL_LARGE_SIDE_ANCHOR) != -1):
		return _finish(false)
	if not await _wait_for_settle(rack2, CELL_LARGE_SIDE_ANCHOR, 0, CargoCatalogue.Size.LARGE, CELL_LARGE_SIDE_PARTNER):
		return _finish(false)
	if not await _until("the Large's body left the world again", func() -> bool:
			return _crates().get_child_count() == crates_before_large_refloor - 1):
		return _finish(false)

	# --- 21: a Large sheds as one crate. ---
	#
	# First, free rack_wall's whole top row: crate_11, the step-15 sentinel,
	# is still racked in CELL_TOP_A (10) and CELL_TOP_B (11) has been empty
	# since step 8's own shed. Retrieved through the real path so nothing
	# stale is left in the row this step is about to fill.
	var crates_before_sentinel_retrieve := _crates().get_child_count()
	var sentinel_retrieved := await _retrieve(rack, CELL_TOP_A, HOST_LATERAL)
	if sentinel_retrieved == null:
		_fail("retrieve the sentinel %s from cell %d" % [CRATE_MEDIUM_BLOCK_NAME, CELL_TOP_A], "never granted")
		return _finish(false)
	if not await _until("the sentinel's body left the world", func() -> bool:
			return _crates().get_child_count() == crates_before_sentinel_retrieve + 1):
		return _finish(false)
	await _release_held()

	# A synthetic fill, exactly as step 3's eight fillers were -- setup, not
	# the thing under test, but it travels over the same _cell_filled
	# broadcast a real placement uses, so both peers' copies are genuinely
	# occupied, not merely asserted so on the host's own say-so. Landed on
	# cells 8/9 -- untouched, permanently unaimable, and irrelevant to aim
	# here since this never goes through Carrier at all.
	var shed_large_record := CargoCatalogue.mint(
		&"machine_parts", CargoCatalogue.variants(&"machine_parts")[0], CargoCatalogue.Size.LARGE,
		FILLER_STORE_UNTIL_DAY, FILLER_OWNER, FILLER_CONTRACT_DAYS, SHED_LARGE_ID,
	).to_dict()
	authority._cell_filled.rpc(
		rack.name, CELL_SHED_LARGE_ANCHOR, shed_large_record, rack.cell_to_global_position(CELL_SHED_LARGE_ANCHOR),
		StorageGrid.Orientation.SIDE_BY_SIDE,
	)
	if not await _until("the synthetic Large fills cells %d+%d" % [CELL_SHED_LARGE_ANCHOR, CELL_SHED_LARGE_PARTNER], func() -> bool:
			return rack.occupied_count(CELL_SHED_LARGE_ANCHOR) == 1 and rack.occupied_count(CELL_SHED_LARGE_PARTNER) == 1):
		return _finish(false)

	# The same impact this file already proved sheds a row in step 8 -- the
	# ImpactSensor is one volume per RACK, not per cell, so the impactor's
	# own path does not need to pass near cells 8/9 specifically. crate_2
	# (the step-8 impactor, loose since step 9's stacking check) is reused.
	var large_impactor := _crate_named(CRATE_FULL_ATTEMPT_NAME)
	if large_impactor == null:
		_fail("find %s" % CRATE_FULL_ATTEMPT_NAME, "not present under Crates")
		return _finish(false)
	_ensure_awake(large_impactor)
	large_impactor.global_position = (rack.global_position
			+ rack.global_transform.basis.x * IMPACT_LATERAL_OFFSET
			+ rack.global_transform.basis.z * IMPACT_START_OFFSET_Z
			+ Vector3.UP * IMPACT_HEIGHT)
	large_impactor.sleeping = false
	large_impactor.linear_velocity = -rack.global_transform.basis.z * IMPACT_SPEED
	large_impactor.angular_velocity = Vector3.ZERO

	var crates_before_large_shed := _crates().get_child_count()
	if not await _until("the impact sheds the synthetic Large's cell %d" % CELL_SHED_LARGE_ANCHOR, func() -> bool:
			return rack.occupied_count(CELL_SHED_LARGE_ANCHOR) == 0):
		return _finish(false)
	_expect_now(
		rack.occupied_count(CELL_SHED_LARGE_PARTNER) == 0,
		"both halves cleared together -- cell %d, not just the anchor" % CELL_SHED_LARGE_PARTNER,
	)
	if not await _until("the shed spent exactly ONE new body -- a Large sheds once, not twice", func() -> bool:
			return _crates().get_child_count() == crates_before_large_shed + 1):
		return _finish(false)
	if not await _until("the shed Large's racked visual is gone", func() -> bool:
			return rack.get_node_or_null("RackedItems/Cell%d_Item0" % CELL_SHED_LARGE_ANCHOR) == null):
		return _finish(false)

	# The host's own view of everything above is already correct here --
	# call_local applies its own broadcasts synchronously -- but the CLIENT's
	# matching checks each depend on an RPC (the Large round trip and shed
	# among them, steps 17-21) actually reaching the wire before quit() tears
	# the peer down. get_tree().quit() does not wait for a pending reliable
	# send to flush, so finishing immediately after issuing one raced the
	# packet out from under itself the first time this scenario was run to a
	# clean pass. Real wall time, not frames, for the same reason
	# SPAWN_SETTLE_MS in carry_session.gd is: headless runs uncapped, so a
	# frame count buys no fixed amount of real time for the network to
	# actually do anything.
	var settle_deadline := Time.get_ticks_msec() + EXIT_SETTLE_MS
	while Time.get_ticks_msec() < settle_deadline:
		await get_tree().process_frame

	_finish(true)


# ------------------------------------------------------------- client role

func _run_client(rack: Rack, rack2: Rack) -> void:
	# Captured NOW, before step 1 even begins, not down at step 13 where it is
	# actually used. crate_10 is untouched by every step before 13 on EITHER
	# peer, but the host's own step 13 mutates its record and then frees the
	# body outright — and this scenario's two scripts are not lockstep in
	# wall-clock terms (the host's own steps 1-12 are all self-driven; this
	# peer only reacts to replicated results), so there is no guarantee the
	# client would still reach this line before the host's mutation if it
	# waited until "step 13" to read it. crate_round.record is never itself a
	# replicated field (see _mutated_roundtrip_record's own doc comment), so
	# THIS peer's pristine copy is the only chance to capture the baseline
	# the host's own mutation will be applied on top of.
	var crate_round_baseline := _crate_named(CRATE_ROUNDTRIP_NAME)
	if crate_round_baseline == null:
		_fail("find %s" % CRATE_ROUNDTRIP_NAME, "not present under Crates")
		return _finish(false)
	var expected_round_record := _mutated_roundtrip_record(crate_round_baseline.record.to_dict())

	# Captured NOW too, for the same reason -- but a simpler one, since
	# nothing in this scenario ever mutates a Large's own record the way step
	# 13 mutates crate_round's. This only has to happen before the host's own
	# step 17 frees the body outright (request_place's queue_free()), and
	# "captured at the top of the function" already guards against that.
	var crate_large_side_baseline := _crate_named(CRATE_LARGE_SIDE_NAME)
	if crate_large_side_baseline == null:
		_fail("find %s" % CRATE_LARGE_SIDE_NAME, "not present under Crates")
		return _finish(false)
	var expected_large_side_record: Dictionary = crate_large_side_baseline.record.to_dict().duplicate(true)

	# --- 1: wait for the host to rack crate_0, then check our own copy. ---
	if not await _until("host racked crate_0 into cell %d" % CELL_A, func() -> bool:
			return rack.occupied_count(CELL_A) == 1):
		return _finish(false)
	# Polled, not checked once: queue_free() replicates its own despawn as a
	# separate message from the _cell_filled broadcast, so there is no
	# ordering guarantee between "the cell shows it" and "the body is
	# actually gone on this peer" landing in the same polled frame.
	if not await _until("the client's own view already lost the body too", func() -> bool:
			return _crates().get_child_count() == EXPECTED_CRATES - 1):
		return _finish(false)
	_expect_now(
		rack.get_node_or_null("RackedItems/Cell%d_Item0" % CELL_A) != null,
		"the client's own view shows cell %d's racked visual" % CELL_A,
	)
	if not await _wait_for_settle(rack, CELL_A, 0):
		return _finish(false)

	# --- 2: client racks crate_1 into the same cell. ---
	var crate_client := _crate_named(CRATE_CLIENT_NAME)
	if crate_client == null:
		_fail("find %s" % CRATE_CLIENT_NAME, "not present under Crates")
		return _finish(false)

	await _grab(crate_client)
	if not await _until("client holds %s" % CRATE_CLIENT_NAME, func() -> bool:
			return crate_client.holder_count() == 1):
		return _finish(false)

	await _place(rack, CELL_A, CLIENT_LATERAL)
	if not await _until("cell %d now holds two" % CELL_A, func() -> bool:
			return rack.occupied_count(CELL_A) == 2):
		return _finish(false)
	if not await _until("both bodies are gone from the client's own view too", func() -> bool:
			return _crates().get_child_count() == EXPECTED_CRATES - 2):
		return _finish(false)
	# This is the client's own placement, checked on the client's own copy --
	# the non-host-initiated case, on the peer that actually asked for it.
	if not await _wait_for_settle(rack, CELL_A, 1):
		return _finish(false)

	# --- 3: wait for the host to fill CELL_B. ---
	if not await _until("cell %d filled to capacity" % CELL_B, func() -> bool:
			return rack.occupied_count(CELL_B) == FILLER_COUNT):
		return _finish(false)

	# --- 4: attempt to place a loose crate into the full cell. Refused. ---
	var crate_full_attempt := _crate_named(CRATE_FULL_ATTEMPT_NAME)
	if crate_full_attempt == null:
		_fail("find %s" % CRATE_FULL_ATTEMPT_NAME, "not present under Crates")
		return _finish(false)

	await _grab(crate_full_attempt)
	if not await _until("client holds %s" % CRATE_FULL_ATTEMPT_NAME, func() -> bool:
			return crate_full_attempt.holder_count() == 1):
		return _finish(false)

	var carrier: Carrier = _me().get_node("Carrier")
	await _attempt_place(rack, CELL_B, CLIENT_LATERAL)
	if not await _stays("refused: still holding %s, cell %d still full" % [CRATE_FULL_ATTEMPT_NAME, CELL_B],
			func() -> bool:
				return (carrier.held_crate() == crate_full_attempt
						and rack.occupied_count(CELL_B) == FILLER_COUNT)):
		return _finish(false)

	# Hands free again before the next grab -- request_grab refuses outright
	# while already holding something, so the refused crate has to go down
	# (an ordinary drop, unchanged from Phase 0) before crate_3 can be picked
	# up. The host's own check above already ran and finished by this point.
	await _release_held()

	# --- 5: drag a different crate, attempt cell A (not floor level). Refused. ---
	var crate_drag_attempt := _crate_named(CRATE_DRAG_ATTEMPT_NAME)
	if crate_drag_attempt == null:
		_fail("find %s" % CRATE_DRAG_ATTEMPT_NAME, "not present under Crates")
		return _finish(false)

	await _grab(crate_drag_attempt, true)
	if not await _until("client is dragging %s" % CRATE_DRAG_ATTEMPT_NAME, func() -> bool:
			return carrier.is_dragging()):
		return _finish(false)

	await _attempt_place(rack, CELL_A, CLIENT_LATERAL, true)
	if not await _stays(
			"ADR 19: still dragging %s, cell %d untouched" % [CRATE_DRAG_ATTEMPT_NAME, CELL_A],
			func() -> bool:
				return (carrier.is_dragging() and carrier.held_crate() == crate_drag_attempt
						and rack.occupied_count(CELL_A) == 2)):
		return _finish(false)

	# Drop it -- this is the host's signal that step 6 (which empties cell A)
	# is safe to start. Without it, the host's own matching check (which
	# finishes sooner, since it has no walk-and-press-three-times of its own
	# to do first) can start retrieving from cell A while this check is
	# still reading it, which is exactly what happened before this existed.
	await _release_held()

	# --- 6: wait for the host to empty cell A via two retrievals. ---
	if not await _until("cell %d is empty" % CELL_A, func() -> bool: return rack.is_cell_empty(CELL_A)):
		return _finish(false)
	# Polled, not checked once: the same deferred-queue_free race as the
	# Crates.get_child_count() checks above. get_node_or_null() still finds a
	# node between queue_free() being called and the removal actually
	# running, so a check landing in that gap reads as a real failure for a
	# race that was never one — this one did exactly that the first time this
	# scenario passed everything else.
	if not await _until("the client's own view shows cell %d's visual gone" % CELL_A, func() -> bool:
			return rack.get_node_or_null("RackedItems/Cell%d_Item0" % CELL_A) == null):
		return _finish(false)
	if not await _until("the client's own view has every crate id back as a body", func() -> bool:
			return _crates().get_child_count() == EXPECTED_CRATES):
		return _finish(false)

	# --- 7: wait for the host to fill both top-row cells for the shed test. ---
	if not await _until("cell %d holds the shed setup" % CELL_TOP_A, func() -> bool:
			return rack.occupied_count(CELL_TOP_A) == 1):
		return _finish(false)
	if not await _wait_for_settle(rack, CELL_TOP_A, 0):
		return _finish(false)
	if not await _until("cell %d holds the shed setup" % CELL_TOP_B, func() -> bool:
			return rack.occupied_count(CELL_TOP_B) == 1):
		return _finish(false)
	if not await _wait_for_settle(rack, CELL_TOP_B, 0):
		return _finish(false)

	# Baselines, recorded independently on this peer's own copy -- the point
	# of proving both peers agree is that neither one is taking the other's
	# word for it.
	var crates_before_shed := _crates().get_child_count()
	var cell_b_before_shed := rack.occupied_count(CELL_B)

	# --- 8: the host launches the impact; confirm the shed on this peer's
	# own copy, not the host's say-so. ---
	if not await _until("the impact sheds cell %d" % CELL_TOP_A, func() -> bool:
			return rack.occupied_count(CELL_TOP_A) == 0):
		return _finish(false)
	if not await _until("the impact sheds cell %d" % CELL_TOP_B, func() -> bool:
			return rack.occupied_count(CELL_TOP_B) == 0):
		return _finish(false)
	_expect_now(
		rack.occupied_count(CELL_B) == cell_b_before_shed,
		"the bound holds: cell %d (not top row) is untouched by the shed" % CELL_B,
	)
	if not await _until("the shed spent exactly two new bodies", func() -> bool:
			return _crates().get_child_count() == crates_before_shed + 2):
		return _finish(false)
	if not await _until("cell %d's racked visual is gone after the shed" % CELL_TOP_A, func() -> bool:
			return rack.get_node_or_null("RackedItems/Cell%d_Item0" % CELL_TOP_A) == null):
		return _finish(false)
	if not await _until("cell %d's racked visual is gone after the shed" % CELL_TOP_B, func() -> bool:
			return rack.get_node_or_null("RackedItems/Cell%d_Item0" % CELL_TOP_B) == null):
		return _finish(false)

	# --- 9: floor stacking still works, confirmed on this peer's own copy. ---
	var stack_top := _crate_named(CRATE_DRAG_ATTEMPT_NAME)
	if stack_top == null:
		_fail("find %s" % CRATE_DRAG_ATTEMPT_NAME, "not present under Crates")
		return _finish(false)
	if not await _until("the stacked crate rests on top rather than sinking through", func() -> bool:
			return stack_top.global_position.y > STACK_SETTLED_MIN_Y):
		return _finish(false)

	# --- 10: regression - retrieval beside a loaded top row does not shed,
	# confirmed on the client's own copy too. ---
	if not await _until("cell %d holds the regression setup" % CELL_TOP_A, func() -> bool:
			return rack2.occupied_count(CELL_TOP_A) == 1):
		return _finish(false)
	if not await _wait_for_settle(rack2, CELL_TOP_A, 0):
		return _finish(false)
	if not await _until("cell %d holds the regression setup" % CELL_TOP_B, func() -> bool:
			return rack2.occupied_count(CELL_TOP_B) == 1):
		return _finish(false)
	if not await _wait_for_settle(rack2, CELL_TOP_B, 0):
		return _finish(false)

	var crates_before_gate_retrieve := _crates().get_child_count()
	if not await _until("cell %d empties (the host's retrieval)" % CELL_TOP_A, func() -> bool:
			return rack2.is_cell_empty(CELL_TOP_A)):
		return _finish(false)
	# Waited for, not checked in the same breath as the stays-window below —
	# see the matching comment in _run_host. _cell_cleared and the
	# retrieval's own crate spawn are two separate reliable messages with no
	# guarantee they land on this peer in the same polled frame, so the cell
	# can already read empty here while the client's own crate count has not
	# caught up yet.
	if not await _until("the retrieval spent exactly one new body, on the client's own view too", func() -> bool:
			return _crates().get_child_count() == crates_before_gate_retrieve + 1):
		return _finish(false)
	if not await _stays(
			"regression: cell %d (beside the retrieval) is untouched on the client's own view" % CELL_TOP_B,
			func() -> bool:
				return (rack2.occupied_count(CELL_TOP_B) == 1
						and _crates().get_child_count() == crates_before_gate_retrieve + 1)):
		return _finish(false)

	# --- 11: regression - a crate stranded inside a cell sensor is
	# grabbable, confirmed on the client's own copy too. ---
	if not await _until("client sees %s become held (the stranded-crate grab)" % CRATE_GATE_STRANDED_NAME, func() -> bool:
			var crate := _crate_named(CRATE_GATE_STRANDED_NAME)
			return crate != null and crate.holder_count() == 1):
		return _finish(false)

	# --- 12: regression - a genuine maximum-range placement, confirmed on
	# the client's own copy too. ---
	if not await _until("cell %d holds the max-range placement" % CELL_B, func() -> bool:
			return rack2.occupied_count(CELL_B) == 1):
		return _finish(false)
	if not await _wait_for_settle(rack2, CELL_B, 0):
		return _finish(false)

	# --- 13: STORE-07, the round trip, field for field, confirmed on this
	# peer's own copy too. expected_round_record was captured at the top of
	# this function, before the host's own mutation could have happened. ---
	if not await _until("cell %d holds the round-trip record" % CELL_ROUNDTRIP, func() -> bool:
			return rack.occupied_count(CELL_ROUNDTRIP) == 1):
		return _finish(false)
	if not await _wait_for_settle(rack, CELL_ROUNDTRIP, 0):
		return _finish(false)
	_expect_record_matches(
		"client: cell %d's own stored record matches the captured one" % CELL_ROUNDTRIP,
		expected_round_record, rack.occupant_record(CELL_ROUNDTRIP),
	)

	if not await _until("cell %d is empty again after the round-trip retrieval" % CELL_ROUNDTRIP, func() -> bool:
			return rack.is_cell_empty(CELL_ROUNDTRIP)):
		return _finish(false)
	if not await _until("the round-tripped crate reappears as a held body on this peer's own view", func() -> bool:
			return _find_held_crate() != null):
		return _finish(false)
	var round_retrieved_client := _find_held_crate()
	_expect_now(
		round_retrieved_client.id != int(expected_round_record["id"]),
		"client: the retrieved body is a NEW mint (id %d), not the same object that was racked (id %d) -- by design, not a bug" % [round_retrieved_client.id, int(expected_round_record["id"])],
	)
	_expect_record_matches(
		"client: retrieved record matches the captured one",
		expected_round_record, round_retrieved_client.record.to_dict(), true,
	)
	if not await _until("client sees %s released again" % CRATE_ROUNDTRIP_NAME, func() -> bool:
			return round_retrieved_client.holder_count() == 0):
		return _finish(false)

	# --- 14: a Medium round trip, confirmed on this peer's own copy. ---
	if not await _until("cell %d holds exactly one Medium" % CELL_MEDIUM, func() -> bool:
			return rack.occupied_count(CELL_MEDIUM) == 1):
		return _finish(false)
	if not await _wait_for_settle(rack, CELL_MEDIUM, 0, CargoCatalogue.Size.MEDIUM):
		return _finish(false)
	_expect_now(
		int(rack.occupant_record(CELL_MEDIUM).get("size", -1)) == CargoCatalogue.Size.MEDIUM,
		"client: cell %d's stored record is a Medium, not eight Small slots" % CELL_MEDIUM,
	)

	if not await _until("cell %d is empty after the Medium is retrieved" % CELL_MEDIUM, func() -> bool:
			return rack.is_cell_empty(CELL_MEDIUM)):
		return _finish(false)
	if not await _until("client's own view shows cell %d's visual gone" % CELL_MEDIUM, func() -> bool:
			return rack.get_node_or_null("RackedItems/Cell%d_Item0" % CELL_MEDIUM) == null):
		return _finish(false)

	# --- 15: heavy retrieval. No client-side assertion of the drag-mode/Y
	# checks (those are host-authoritative-truth checks, made on the peer
	# that actually did the retrieving) — this peer only confirms the
	# structural outcome, the same shape every earlier step's own client
	# role already follows. ---
	if not await _until("cell %d holds the sentinel before the heavy retrieval" % CELL_TOP_A, func() -> bool:
			return rack.occupied_count(CELL_TOP_A) == 1):
		return _finish(false)
	if not await _wait_for_settle(rack, CELL_TOP_A, 0):
		return _finish(false)

	if not await _until("cell %d is empty again after the heavy retrieval" % CELL_ROUNDTRIP, func() -> bool:
			return rack.is_cell_empty(CELL_ROUNDTRIP)):
		return _finish(false)
	_expect_now(
		rack.occupied_count(CELL_TOP_A) == 1,
		"client: the rack did not shed its sentinel (cell %d) during the heavy retrieval" % CELL_TOP_A,
	)

	# --- 16: a late joiner sees CONTENTS, not just counts — the host's
	# manually-addressed _rack_snapshot lands here. ---
	if not await _until("client's copy of rack_island cell %d carries a real record after the snapshot" % CELL_B, func() -> bool:
			var record := rack2.occupant_record(CELL_B)
			return record.get("category", &"") == &"dodgy" and int(record.get("size", -1)) == CargoCatalogue.Size.SMALL):
		return _finish(false)

	# --- 17: a Large takes two cells, side by side -- confirmed on this
	# peer's own copy too. ---
	if not await _until("rack_island cell %d holds the Large, side by side" % CELL_LARGE_SIDE_ANCHOR, func() -> bool:
			return rack2.occupied_count(CELL_LARGE_SIDE_ANCHOR) == 1):
		return _finish(false)
	if not await _wait_for_settle(rack2, CELL_LARGE_SIDE_ANCHOR, 0, CargoCatalogue.Size.LARGE, CELL_LARGE_SIDE_PARTNER):
		return _finish(false)
	_expect_now(
		rack2.occupied_count(CELL_LARGE_SIDE_PARTNER) == 1,
		"client: the SIDE_BY_SIDE partner cell %d is occupied too, not just the anchor" % CELL_LARGE_SIDE_PARTNER,
	)
	_expect_now(
		rack2.occupant(CELL_LARGE_SIDE_ANCHOR) == rack2.occupant(CELL_LARGE_SIDE_PARTNER),
		"client: both halves report the SAME crate id -- one Large, not two",
	)

	# --- 18: front-to-back, into the wall rack's dead row -- the assertion
	# that matters most, confirmed here too. ---
	if not await _until("rack_wall's permanently unaimable cell %d is filled" % CELL_LARGE_FRONT_PARTNER, func() -> bool:
			return rack.occupied_count(CELL_LARGE_FRONT_PARTNER) == 1):
		return _finish(false)
	if not await _wait_for_settle(rack, CELL_LARGE_FRONT_ANCHOR, 0, CargoCatalogue.Size.LARGE, CELL_LARGE_FRONT_PARTNER):
		return _finish(false)
	_expect_now(
		rack.cell_orientation(CELL_LARGE_FRONT_ANCHOR) == StorageGrid.Orientation.FRONT_TO_BACK,
		"client: the STORED orientation itself reads FRONT_TO_BACK -- not a hard-coded SIDE_BY_SIDE default",
	)

	# --- 19: retrieval hands back one crate, field for field, confirmed on
	# this peer's own copy too. expected_large_side_record was captured at
	# the top of this function, before the host ever touched crate_15. ---
	if not await _until("rack_island cells %d and %d are empty after the retrieval" % [CELL_LARGE_SIDE_ANCHOR, CELL_LARGE_SIDE_PARTNER], func() -> bool:
			return rack2.is_cell_empty(CELL_LARGE_SIDE_ANCHOR) and rack2.is_cell_empty(CELL_LARGE_SIDE_PARTNER)):
		return _finish(false)
	if not await _until("rack_island's racked visual is gone after the retrieval, on the client's own view too", func() -> bool:
			return rack2.get_node_or_null("RackedItems/Cell%d_Item0" % CELL_LARGE_SIDE_ANCHOR) == null):
		return _finish(false)
	if not await _until("the retrieved Large reappears as a held body on this peer's own view", func() -> bool:
			return _find_held_crate() != null):
		return _finish(false)
	var large_retrieved_client := _find_held_crate()
	_expect_now(
		large_retrieved_client.id != int(expected_large_side_record["id"]),
		"client: the retrieved body is a NEW mint (id %d), not the same object that was racked (id %d) -- by design" % [large_retrieved_client.id, int(expected_large_side_record["id"])],
	)
	_expect_record_matches(
		"client: retrieved Large's record matches the one captured before it was ever racked",
		expected_large_side_record, large_retrieved_client.record.to_dict(), true,
	)

	# --- 20: the dragged Large is refused above the floor, then succeeds at
	# floor level. The refusal itself is a host-authoritative-truth check
	# made on the peer that attempted it (same convention step 15 already
	# follows); this peer confirms the STRUCTURAL result -- cell A is never
	# written to by anything else in this whole file, so it still being empty
	# here is exactly what "refused" looks like from outside. ---
	if not await _until("the Large is racked back into cell %d at floor level" % CELL_LARGE_SIDE_ANCHOR, func() -> bool:
			return rack2.occupant(CELL_LARGE_SIDE_ANCHOR) != -1):
		return _finish(false)
	_expect_now(
		rack2.is_cell_empty(CELL_A),
		"client: cell %d (the refused non-floor attempt) was never actually filled" % CELL_A,
	)
	if not await _wait_for_settle(rack2, CELL_LARGE_SIDE_ANCHOR, 0, CargoCatalogue.Size.LARGE, CELL_LARGE_SIDE_PARTNER):
		return _finish(false)

	# --- 21: a Large sheds as one crate, confirmed on this peer's own copy. ---
	if not await _until("the sentinel %s leaves rack_wall cell %d" % [CRATE_MEDIUM_BLOCK_NAME, CELL_TOP_A], func() -> bool:
			return rack.is_cell_empty(CELL_TOP_A)):
		return _finish(false)
	if not await _until("the synthetic Large fills cells %d+%d" % [CELL_SHED_LARGE_ANCHOR, CELL_SHED_LARGE_PARTNER], func() -> bool:
			return rack.occupied_count(CELL_SHED_LARGE_ANCHOR) == 1 and rack.occupied_count(CELL_SHED_LARGE_PARTNER) == 1):
		return _finish(false)

	# Baseline, recorded independently on this peer's own copy -- same
	# reasoning as crates_before_shed above (steps 7/8).
	var crates_before_large_shed_client := _crates().get_child_count()

	if not await _until("the impact sheds the synthetic Large's cell %d, on the client's own view too" % CELL_SHED_LARGE_ANCHOR, func() -> bool:
			return rack.occupied_count(CELL_SHED_LARGE_ANCHOR) == 0):
		return _finish(false)
	_expect_now(
		rack.occupied_count(CELL_SHED_LARGE_PARTNER) == 0,
		"client: both halves cleared together -- cell %d, not just the anchor" % CELL_SHED_LARGE_PARTNER,
	)
	if not await _until("the shed spent exactly ONE new body, on the client's own view too", func() -> bool:
			return _crates().get_child_count() == crates_before_large_shed_client + 1):
		return _finish(false)

	_finish(true)


# -------------------------------------------------------------- action helpers

## Host-only. A crate left loose and untouched for half a second settles to a
## frozen, immovable body (ADR 17, 01-09) — which several direct-manipulation
## tricks below now run straight into, since a frozen body ignores both an
## assigned velocity and gravity: setting position teleports it (a transform
## write, unaffected by freeze), but it then just sits at the new position
## forever, never travelling anywhere and never falling. Both steps 8 and 9
## reuse crates ([constant CRATE_FULL_ATTEMPT_NAME], [constant
## CRATE_DRAG_ATTEMPT_NAME]) that have been sitting loose and unclaimed for
## several real seconds by the time they get here — comfortably past
## [member Crate.settle_frames] — so both need this first.
##
## Mirrors [method Crate._wake] rather than calling it: that method is
## host-only and private by convention, and this is test code reaching into
## a crate's own fields exactly the way the direct-manipulation tricks below
## already do legitimately — a crate is always simulated for real on the
## host (see [code]_take()[/code]'s own docstring in carry_session.gd).
func _ensure_awake(crate: Crate) -> void:
	crate.sync_settled = false
	crate.collision_layer &= ~Crate.LAYER_WORLD
	crate.freeze = false
	crate.sleeping = false


## Teleport to the crate's row and press until it is ours.
func _grab(crate: Crate, want_drag := false) -> void:
	var me := _me()
	var carrier: Carrier = me.get_node("Carrier")
	me.teleport_to(Vector3(crate.global_position.x, STAND_HEIGHT, crate.global_position.z + GRAB_STAND_OFFSET_Z))

	var deadline := Time.get_ticks_msec() + STEP_TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		if carrier.held_crate() == crate:
			break
		me.aim_at(crate.global_position)
		carrier.try_toggle_hold(want_drag)
		for _i in 6:
			await get_tree().process_frame

	# Look level afterward, the same reason carry_session does: keeping the
	# aim pointed down at the floor leaves later reach checks a coin toss.
	var level := Vector3(crate.global_position.x, me.camera.global_position.y, crate.global_position.z)
	me.aim_at(level)


## A held crate does not teleport with its holder — it has to physically fly
## to the new hold point every physics frame — so [method _walk_to] closes
## ground in small steps rather than one jump, whether or not anything is
## currently held. Paced by [b]wall-clock time[/b], not a frame count:
## headless Godot runs uncapped, so idle frames can fire far faster than the
## fixed 60 Hz physics tick, and a frame count between steps was measured to
## buy almost no real physics time for the spring to catch up — the very
## first walk in this scenario silently dropped its crate for exactly that
## reason before this was paced by the clock instead.
##
## Kept at or below the in-game drag speed penalty (40% of the 4.2 m/s walk
## speed, so ~1.68 m/s — GDD §6.1) rather than any faster carry speed: the
## drag spring is deliberately softer than the carry one (900 vs 2400
## stiffness) and a walk paced for carry snapped the drag hold mid-transit
## the first time this scenario tried to walk a dragged crate to a cell.
const WALK_SPEED_MPS := 1.5
## How often, in real time, the walk advances the hold point. Small and
## clock-paced, so several physics ticks land inside every step.
const WALK_TICK_MS := 50


## Move the local player toward [param destination] at [constant WALK_SPEED_MPS],
## paced by real elapsed time. See the constants' own doc for why.
func _walk_to(destination: Vector3) -> void:
	var me := _me()
	var carrier: Carrier = me.get_node("Carrier")
	var start := me.global_position
	var distance := start.distance_to(destination)
	if distance < 0.01:
		return
	var duration_ms := int(ceil((distance / WALK_SPEED_MPS) * 1000.0))
	var start_time := Time.get_ticks_msec()
	var deadline := start_time + duration_ms
	# A held crate follows a teleport by SPRING, never instantly, and this
	# hard ceiling is what stops a crate that will genuinely never catch up
	# (already broken some other way) from hanging this function forever --
	# see _wait_for_crate_catch_up's own doc comment for the failure this
	# whole mechanism exists to prevent.
	var hard_ceiling := deadline + STEP_TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		if not await _wait_for_crate_catch_up(me, carrier, hard_ceiling):
			break
		var elapsed := Time.get_ticks_msec() - start_time
		var t := clampf(float(elapsed) / float(duration_ms), 0.0, 1.0)
		me.teleport_to(start.lerp(destination, t))
		var tick_deadline := Time.get_ticks_msec() + WALK_TICK_MS
		while Time.get_ticks_msec() < tick_deadline:
			await get_tree().process_frame
	await _wait_for_crate_catch_up(me, carrier, hard_ceiling)
	me.teleport_to(destination)


## Pauses in place (no further teleporting) until whatever [param carrier] is
## holding, if anything, is close enough to its holder to survive landing at
## the DESTINATION of the next teleport step. Returns true immediately if
## nothing is held. Returns false only once [param ceiling_ms] passes without
## catching up — accepting the risk rather than hanging [method _walk_to]
## forever on a crate that will never close the gap (already broken loose
## some other way).
##
## Exists because a held crate follows the hold point by spring, not by
## teleport: [method _walk_to]'s own jumps are normally small enough
## (WALK_TICK_MS apart) for the spring to keep pace, but a long enough walk,
## or one where the holder's OWN facing (fixed since the last [method
## Player.aim_at] call — see [member Crate._apply_carry_forces]'s hold point,
## computed from the CURRENT camera transform) points somewhere other than
## the direction of travel, can silently exceed [member Crate.break_distance]
## / [member Crate.drag_break_distance] mid-transit. The break itself prints
## nothing ([method Crate._break_hold]), so the only visible symptom is a
## crate stranded wherever the walk happened to be at the moment it broke —
## which then goes on to hijack a completely unrelated aim ray later, since
## a loose crate sitting near a rack's approach corridor blocks the ray to
## whatever is behind it. Found live by this plan's own suite, not reasoned
## about in advance: the exact stranding position was caught with a
## temporary print in Crate._break_hold (never committed).
##
## The reference point differs by hold mode for the reason
## [method Crate._apply_drag_forces]'s own doc comment gives: a drag's hold
## point comes from the capsule's yaw at FLOOR height, not the camera at eye
## height, so measuring a drag against the camera would put it a permanent
## ~1.7 m "away" (the standing height alone) and this wait would spin for
## its own full ceiling on every single drag walk in the file.
func _wait_for_crate_catch_up(me: Player, carrier: Carrier, ceiling_ms: int) -> bool:
	while Time.get_ticks_msec() < ceiling_ms:
		var held := carrier.held_crate()
		if held == null:
			return true
		var reference := me.global_position if carrier.is_dragging() else me.camera.global_position
		if held.global_position.distance_to(reference) < CARRY_CATCH_UP_DISTANCE:
			return true
		await get_tree().process_frame
	return false


## South of TestRoom's crate row (CRATE_ROW_ORIGIN.z = -6.0), by a wide
## margin, and clear of the rack, both zones and PARK_POINT alike. Only
## needed for [param avoid_row] in [method _approach_cell] below.
const ROW_DETOUR_Z := -3.0

## A single waypoint, just outside rack_island's own footprint (world x < 6.5;
## its ImpactSensor's own x-span is [6.4, 8.6], z-span [1.55, 2.45] — this
## clears the wider figure with margin on the approach side that matters).
## Only needed for [param avoid_rack_island] in [method _approach_cell] below.
##
## Added at the wave 7 gate (2026-08-21) when GRAB_STAND_OFFSET_Z shortened
## alongside the rest of the reach chain (2.5 -> 2.0 m). A held crate walked
## straight from the crate row to rack_island's own top-row cells crosses
## this rack's footprint partway through the journey — harmless while
## rack_island holds nothing yet (Rack._on_impact's own is_empty() guard
## skips it outright), but once crate_6 already occupies cell 10, the same
## crossing sheds it back out from under crate_7's own placement moments
## later: request_retrieve then finds cell 10 already empty, try_toggle_hold
## resolves the loose shed crate sitting in the way instead of the cell, and
## the retrieval "succeeds" on a plain grab that never mints a new body —
## read as a hang on "the retrieval spent exactly one new body". Reproduced
## with GRAB_REACH, PLACE_REACH and the ray all held at their OLD values and
## only GRAB_STAND_OFFSET_Z moved, so this is specifically about where the
## walk starts, not about any of the reach distance checks.
##
## Deliberately not the same shape as [param avoid_row]'s two-axis-aligned-
## legs detour (via [constant ROW_DETOUR_Z]) — that shape adds roughly 6.5 m
## to this particular walk, which blew the client's own 15 s wait for the
## replicated placement to land (found running this fix the first time).
## This point instead hugs the ImpactSensor's own near corner from outside:
## the first leg holds x < 6.4 throughout (this point's own x is left of the
## sensor entirely, so a straight line from anywhere further left/south never
## crosses into it), and the second leg holds z > 2.45 throughout (this
## point's own z already clears the sensor, and both top-row cells sit
## further north in z again, so z only rises from here) — safe by
## construction on both legs, for a two-segment path barely longer than the
## direct one it replaces (measured ~15.9 m against the direct ~15.8 m).
const RACK_ISLAND_CORNER_WAYPOINT := Vector3(6.1, STAND_HEIGHT, 2.75)

## Walk to a cell and aim at its centre. Shared by every cell interaction.
##
## [param avoid_row] routes via [constant ROW_DETOUR_Z] first rather than
## walking a straight line. Needed once ADR 17 (01-09) landed: crate_4 and
## crate_5 sit untouched in the row for this whole scenario (01-07's own
## reservation, still unclaimed at this point) and settle to real, immovable
## world geometry after half a second at rest. The rack's own approach point
## sits barely south of the row itself (z=-6.5 against the row's z=-6.0), so
## a straight walk from crate_3's own spot east toward the rack drags it
## directly into crate_4's now-solid footprint and wedges it there
## permanently — caught by this scenario's own drag-attempt step timing out
## on a hold that had silently broken. Not needed for anything that does not
## drag a crate through the row: a bare player walk here uses
## [method Player.teleport_to], which bypasses collision entirely, so only a
## dragged crate can actually get physically stuck on the way.
## [param stand_offset_z] defaults to [constant RACK_STAND_OFFSET_Z] — the
## comfortable interior distance every step above this point uses. Regression
## 12 (below) is the one caller that passes something else
## ([constant MAX_RANGE_STAND_OFFSET_Z]), to stand deliberately near the edge
## of GrabRay's own reach rather than well inside it.
## [param avoid_rack_island] is a different shape to [param avoid_row] — a
## single corner-hugging waypoint rather than two axis-aligned legs, because
## the two-leg shape cost too much real time for this particular walk. See
## [constant RACK_ISLAND_CORNER_WAYPOINT]'s own doc comment for both the
## hazard and why the shape differs.
func _approach_cell(rack: Rack, cell_index: int, lateral: float, avoid_row := false,
		stand_offset_z := RACK_STAND_OFFSET_Z, avoid_rack_island := false) -> Vector3:
	var me := _me()
	var target := rack.cell_to_global_position(cell_index)
	if avoid_row:
		await _walk_to(Vector3(me.global_position.x, STAND_HEIGHT, ROW_DETOUR_Z))
		await _walk_to(Vector3(target.x + lateral, STAND_HEIGHT, ROW_DETOUR_Z))
	if avoid_rack_island:
		await _walk_to(RACK_ISLAND_CORNER_WAYPOINT)
	await _walk_to(Vector3(target.x + lateral, STAND_HEIGHT, target.z + stand_offset_z))
	me.aim_at(target)
	return target


## Press until whatever we were holding is no longer in our hands — a
## successful placement. Only for cases the caller expects to succeed; a
## refusal would spin this to its timeout, which is what [method _attempt_place]
## is for instead.
func _place(rack: Rack, cell_index: int, lateral: float,
		stand_offset_z := RACK_STAND_OFFSET_Z, avoid_rack_island := false) -> void:
	var me := _me()
	var carrier: Carrier = me.get_node("Carrier")
	var target := await _approach_cell(rack, cell_index, lateral, false, stand_offset_z, avoid_rack_island)

	var deadline := Time.get_ticks_msec() + STEP_TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		if carrier.held_crate() == null:
			return
		me.aim_at(target)
		carrier.try_toggle_hold()
		for _i in 6:
			await get_tree().process_frame


## A handful of presses at a cell expected to refuse. Deliberately bounded
## rather than looped to success — success here would be the bug.
##
## [param avoid_row] is passed straight through to [method _approach_cell] —
## see its own doc for why the drag-attempt call site below needs it.
func _attempt_place(rack: Rack, cell_index: int, lateral: float, avoid_row := false) -> void:
	var me := _me()
	var carrier: Carrier = me.get_node("Carrier")
	var target := await _approach_cell(rack, cell_index, lateral, avoid_row)

	for _i in 3:
		me.aim_at(target)
		carrier.try_toggle_hold()
		for _j in 6:
			await get_tree().process_frame


## Press until a crate lands in our (previously empty) hands, and return it.
func _retrieve(rack: Rack, cell_index: int, lateral: float) -> Crate:
	var me := _me()
	var carrier: Carrier = me.get_node("Carrier")
	var target := await _approach_cell(rack, cell_index, lateral)

	var deadline := Time.get_ticks_msec() + STEP_TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		if carrier.held_crate() != null:
			return carrier.held_crate()
		me.aim_at(target)
		carrier.try_toggle_hold()
		for _i in 6:
			await get_tree().process_frame
	return null


## Off to the side of both cells' approach corridor (which sits within about
## a metre of x=7.6-8.8, z=-6.5 for this rack), so a crate dropped here never
## ends up in the path of a later raycast at either one -- but close, not
## across the room: WALK_SPEED_MPS is deliberately slow (it has to stay under
## what the drag spring can follow), and this point is visited twice for
## every retrieve-then-release pair. A far corner turned that into two
## multi-second walks per release and made the LIFO retrievals alone take
## longer than the other peer's own wait budget for seeing the result.
const PARK_POINT := Vector3(4.0, STAND_HEIGHT, -6.5)

## How close a held crate must be to its holder for [method _wait_for_crate_catch_up]
## (called from every teleport step [method _walk_to] takes) to consider it
## "keeping up" — comfortably under [member Crate.break_distance] (2.2 m) and
## [member Crate.drag_break_distance] (2.6 m) alike, so this reads as "normal
## hold," not "about to snap," for either mode. See that method's own doc
## comment for the failure this constant exists to prevent.
const CARRY_CATCH_UP_DISTANCE := 1.8


## Walk clear, look somewhere that is neither cargo nor a rack cell, and press
## until our hands are empty — the ordinary Phase 0 release. Walking away
## first (rather than dropping on the spot) is what stops a dropped crate
## from later sitting in the ray's path the next time this rack is aimed at.
##
## [param target] defaults to [constant PARK_POINT] (rack_wall's own safe
## spot) — steps 10-11 pass [constant GATE_PARK_POINT] instead, since a walk
## all the way to PARK_POINT and back left too little of the client's own
## 15 s window for a replication tick to land (see its own doc comment).
func _release_held(target := PARK_POINT) -> void:
	var me := _me()
	var carrier: Carrier = me.get_node("Carrier")
	if carrier.held_crate() == null:
		return
	await _walk_to(target)
	me.aim_at(me.camera.global_position + Vector3(0.0, 5.0, 0.0))

	var deadline := Time.get_ticks_msec() + STEP_TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		if carrier.held_crate() == null:
			return
		carrier.try_toggle_hold()
		for _i in 6:
			await get_tree().process_frame


## Cleanup-only alternative to [method _release_held]: teleports whatever is
## held directly to [param target] and releases it there via the real
## [code]request_release()[/code], instead of walking it there on its own
## spring. Not the thing under test — STORE-07 and everything else this file
## proves about placement/retrieval already happens through the real
## interact path before this is ever called; this exists purely to get a
## crate out of the way of a LATER aim ray without relying on the carry
## spring to escort it somewhere first. Justified by the same precedent the
## impact and stacking steps above already use: "a crate is always simulated
## for real on the host, so setting its transform by hand is a legitimate
## host action, not a workaround." See the one call site's own doc comment
## for the specific carry-torque-versus-rack-upright finding that made this
## necessary instead of [method _release_held].
func _teleport_release(target: Vector3) -> void:
	var me := _me()
	var carrier: Carrier = me.get_node("Carrier")
	var crate := carrier.held_crate()
	if crate == null:
		return
	crate.global_position = target
	crate.linear_velocity = Vector3.ZERO
	crate.angular_velocity = Vector3.ZERO
	var referee := _authority()
	if Net.is_host():
		referee.request_release()
	else:
		referee.request_release.rpc_id(1)


## Polls until the visual at rack/cell_index/sub_index has actually arrived at
## its resting position — the one thing about 01-06's travel-and-settle
## animation a test can genuinely prove. A tween that starts and never
## arrives is the classic tween bug, and it would leave an item visibly
## floating in the aisle on some peers and not others.
##
## Not the bare cell centre for a Small: eight Smalls tile a cell as a 2x2x2
## lattice (StorageGrid.small_offset), so [param sub_index]'s actual target is
## offset from [method Rack.cell_to_local_position] — exactly what
## [code]Rack._spawn_cell_visual[/code] tweens toward. [param size] defaults
## to Small for every pre-02-06 caller, all of which only ever rack Smalls;
## a Medium (02-06) has no sub-lattice of its own and settles at the bare
## cell centre instead ([method StorageGrid.item_offset] already knows this
## distinction — this function delegates to it rather than hard-coding
## [method StorageGrid.small_offset] as it did before, which silently checked
## a Medium against the wrong target and hung this exact wait forever the
## first time a Medium ever raced it, found live by this plan's own suite).
##
## [param partner_index] is new (02-08): a Large's visual settles at the
## PAIR's own midpoint ([method StorageGrid.pair_centre]), not at
## [param cell_index]'s bare centre — [method StorageGrid.item_offset]
## returns [constant Vector3.ZERO] for anything but a Small, which for a
## Large would silently wait on the wrong target (the anchor cell's own
## centre, half a cell short of where [code]Rack._spawn_large_visual[/code]
## actually tweens to) and hang exactly the way the Medium case once did.
## -1 (the default) preserves every existing call site unchanged. [param
## cell_index] must still be the Large's own ANCHOR — [code]Cell%d_Item0[/code]
## is only ever spawned there (see [method Rack._spawn_large_visual]'s own
## doc comment), so [param sub_index] stays 0 for a Large exactly as it
## already is for a Medium.
func _wait_for_settle(rack: Rack, cell_index: int, sub_index: int, size := CargoCatalogue.Size.SMALL, partner_index := -1) -> bool:
	var visual := rack.get_node_or_null("RackedItems/Cell%d_Item%d" % [cell_index, sub_index])
	if visual == null:
		_fail("the placed item settles exactly in its cell", "no visual node Cell%d_Item%d" % [cell_index, sub_index])
		return false
	var target := (
		StorageGrid.pair_centre(cell_index, partner_index) if partner_index != -1
		else rack.cell_to_local_position(cell_index) + StorageGrid.item_offset(size, sub_index)
	)
	return await _until("the placed item settles exactly in its cell", func() -> bool:
			return visual.position.is_equal_approx(target))


func _until(label: String, predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + STEP_TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			_pass(label)
			return true
		await get_tree().process_frame
	_fail(label, "timed out after %d ms" % STEP_TIMEOUT_MS)
	return false


## Assert something stays true for a window, rather than merely becoming true
## once — needed for every refusal here, since "still holding it" is trivially
## true in the first frame regardless of whether the refusal actually worked.
func _stays(label: String, predicate: Callable, window_ms := 500) -> bool:
	var deadline := Time.get_ticks_msec() + window_ms
	while Time.get_ticks_msec() < deadline:
		if not predicate.call():
			_fail(label, "stopped being true before the window closed")
			return false
		await get_tree().process_frame
	_pass(label)
	return true


func _expect_now(condition: bool, label: String) -> void:
	if condition:
		_pass(label)
		return
	_fail(label, "expected true, was false")


## One assertion per field of a [method CargoRecord.to_dict] dictionary,
## naming the field that differs rather than a single "records match"
## boolean — the whole value of STORE-07's own test is saying WHICH field
## broke, not merely that something did (see the deliberate-break check in
## this plan's own verification instructions).
##
## [param skip_id] excludes "id" from the comparison. A freshly RETRIEVED
## crate legitimately gets a brand new id — [code]TestRoom.spawn_crate_at[/code]
## always mints a fresh one, by design, so a live id is never reused while a
## stale reference to the old one might still exist on some peer — and
## REQUIREMENTS.md's own STORE-07 wording allows exactly this: "LIFO
## returning a different crate of the same kind is correct." Every OTHER
## field must still match exactly, whether the record is still sitting in a
## rack cell (id unchanged, so [param skip_id] should be false) or has just
## been re-minted (id changed, so [param skip_id] should be true).
func _expect_record_matches(label_prefix: String, expected: Dictionary, actual: Dictionary, skip_id := false) -> void:
	for key in expected.keys():
		if skip_id and key == "id":
			continue
		var expected_value = expected[key]
		var actual_value = actual.get(key)
		_expect_now(
			expected_value == actual_value,
			"%s: field '%s' matches (expected %s, got %s)" % [label_prefix, key, expected_value, actual_value],
		)


## The SAME deterministic mutation step 13 applies host-side to crate_round's
## own live [CargoRecord], replayed here so the CLIENT can compute the exact
## expected post-mutation dictionary from ITS OWN (still pristine, at the
## point this is called) local copy of that same starting record — [member
## Crate.record] is never itself a replicated field, so the client's own copy
## of crate_round would otherwise never reflect a mutation the host made only
## to its own object. [CargoCondition]/[CargoRecord] are pure and
## deterministic (no nodes, no autoloads, no randomness — see their own class
## comments), so replaying the identical recipe on identical input reliably
## reproduces the identical output on a completely different process.
func _mutated_roundtrip_record(base: Dictionary) -> Dictionary:
	var record := CargoRecord.from_dict(base)
	record.drag_distance = ROUNDTRIP_DRAG_DISTANCE
	var condition := record.condition()
	condition.worsen(2)
	condition.apply_tape()
	record.set_condition(condition)
	return record.to_dict()


## The one crate currently held by anyone, anywhere in the world — used by
## the CLIENT to find a just-retrieved crate whose freshly minted name it has
## no way to predict in advance (ids come from a host-side monotonic
## counter). Safe specifically because, at every point this is called,
## nothing else in this scenario is concurrently holding anything — every
## earlier step releases what it grabbed before moving on.
func _find_held_crate() -> Crate:
	var container := _crates()
	if container == null:
		return null
	for child in container.get_children():
		var crate := child as Crate
		if crate != null and crate.holder_count() > 0:
			return crate
	return null


## The other peer's own id, resolved from [member Net.players] rather than
## assumed — ENet does not guarantee a single client always lands on peer id
## 2, and hardcoding it here would be exactly the kind of unverified
## assumption this project's own standing rules forbid.
func _client_peer_id() -> int:
	for id in Net.players.keys():
		if int(id) != 1:
			return int(id)
	return -1


func _pass(label: String) -> void:
	_steps_passed += 1
	print("[test] ok   %s" % label)


func _fail(label: String, why: String) -> void:
	print("[test] FAIL %s — %s" % [label, why])
	_report_state()


## Printed on failure only: enough state to tell which side disagreed, and
## with what the rack believed, without rerunning anything.
func _report_state() -> void:
	print("[test] state role=%s local_id=%d roster=%d crates=%d" % [
		_role, Net.local_id(), Net.players.size(),
		_crates().get_child_count() if _crates() != null else -1,
	])
	var rack := _rack()
	if rack != null:
		var occ_a := rack.occupied_count(CELL_A)
		var occ_b := rack.occupied_count(CELL_B)
		var visuals := rack.get_node_or_null("RackedItems")
		print("[test] state cell_a=%d/8 cell_b=%d/8 racked_visuals=%d" % [
			occ_a, occ_b, visuals.get_child_count() if visuals != null else -1,
		])
	# rack_island — steps 10-12's own rack, printed separately since rack.gd
	# above is always rack_wall. Added after a gate regression's own failure
	# printed only rack_wall's state, telling nothing about the cells this
	# scenario was actually failing on.
	var rack2 := _rack_island()
	if rack2 != null:
		print("[test] state rack_island top_a=%d/8 top_b=%d/8 cell_a=%d/8 cell_b=%d/8" % [
			rack2.occupied_count(CELL_TOP_A), rack2.occupied_count(CELL_TOP_B),
			rack2.occupied_count(CELL_A), rack2.occupied_count(CELL_B),
		])
	var me := _me()
	if me != null:
		print("[test] state me pos=%v" % me.global_position)


## Silence any still-playing audio before quitting.
##
## This is the fix for a ~50% flaky suite, and the cause is worth recording
## because the symptom pointed nowhere near it. Racking plays a positional
## thud (01-06). The last placement in this scenario happens shortly before
## _finish(), so whether the sound is still in flight when the tree tears down
## is a race -- and when it is, its AudioStreamPlaybackWAV outlives the tree:
##
##     Leaked instance: AudioStreamWAV - Reference count: 1
##     Leaked instance: AudioStreamPlaybackWAV - Reference count: 1
##     Resource still in use: res://assets/audio/rack_place.wav
##
## The suite has zero tolerance for engine warnings, so that one line failed a
## run in which all 93 assertions passed. Diagnosed by running the client with
## --verbose against the editor binary; an earlier attempt missed it because
## the export build does not carry the leaked-object detail.
##
## Stopped rather than waited on: waiting for playback to end is still a race,
## just a narrower one. This is deterministic. Test-harness only -- leaking at
## process exit is harmless in a shipped game, where the OS reclaims it, so
## nothing in production needs to change for this.
func _silence_audio() -> void:
	_stop_players_under(get_tree().root)


func _stop_players_under(node: Node) -> void:
	if node is AudioStreamPlayer3D or node is AudioStreamPlayer:
		node.stop()
	for child: Node in node.get_children():
		_stop_players_under(child)


func _finish(passed: bool) -> void:
	print("[test] RESULT=%s role=%s steps_passed=%d" % [
		"PASS" if passed else "FAIL", _role, _steps_passed,
	])
	_silence_audio()
	# A second pass, after a short real-time gap -- not a duplicate of the
	# call above. 02-06 added several more placements/retrievals (each its
	# own positional thud, 01-06) than any earlier plan in this scenario,
	# and that raised a real, if narrow, race back from the dead: an RPC
	# whose delivery lands in the SAME frame this function starts can spawn
	# a NEW racked-item visual -- and its own thud -- AFTER the first
	# silence pass above, since engine-side RPC delivery and this script's
	# own execution are interleaved, not ordered relative to each other.
	# Found live on this plan's own suite, not reasoned about in advance;
	# see _silence_audio's own doc comment for the original signature this
	# is still guarding against.
	for _i in 12:
		await get_tree().process_frame
	_silence_audio()
	get_tree().quit(0 if passed else 1)


func _crates() -> Node:
	if _world == null:
		return null
	return _world.get_node_or_null("Crates")


func _crate_named(crate_name: String) -> Crate:
	var crates := _crates()
	if crates == null:
		return null
	return crates.get_node_or_null(crate_name) as Crate


func _rack() -> Rack:
	if _world == null:
		return null
	return _world.get_node_or_null(RACK_PATH) as Rack


func _rack_island() -> Rack:
	if _world == null:
		return null
	return _world.get_node_or_null(RACK2_PATH) as Rack


func _authority() -> CarryAuthority:
	if _world == null:
		return null
	return _world.get_node_or_null("CarryAuthority") as CarryAuthority


func _me() -> Player:
	if _world == null:
		return null
	return _world.get_node_or_null("Players/%d" % Net.local_id()) as Player
