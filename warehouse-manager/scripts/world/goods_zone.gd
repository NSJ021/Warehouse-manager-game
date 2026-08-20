class_name GoodsZone
extends Area3D

## The two ends of the loop: Goods IN and Goods OUT. One scene serves both —
## [member kind] picks the label and tint, derived locally on every peer
## rather than sent over the wire.
##
## In Phase 1 a zone only *detects*. Nothing economic hangs off it yet
## (STORE-03); that arrives in Phase 4.
##
## [b]1. Zones need no multiplayer machinery.[/b] They are static level
## content — every peer loads the same scene at the same transform and
## evaluates the same volume against cargo whose transforms are already
## replicated by [Crate] itself. No spawner, no synchronizer, no RPC, no
## handshake, and grepping this file and its scene for either finds none.
##
## [b]2. Near a boundary, host and client can briefly disagree[/b], because a
## client's crate is a puppet easing toward the host's last replicated word
## (see [Crate]'s [member Crate.PUPPET_SMOOTHING]), so [method contents] can
## flicker a crate in or out a frame or two later on a client than on the
## host. Phase 1 only detects, so this is harmless. [b]Whichever later phase
## attaches money or contract fulfilment to a zone must read the host's own
## instance as ground truth and never trust a client-reported list[/b] — the
## same reason [code]CarryAuthority[/code] never trusts a client's opinion
## about anything it can verify itself.
##
## [b]3. A zone cannot see racked stock[/b], because a racked item is not a
## physics body at all (ADR 14) — it is a bare mesh with no collision, so it
## can never enter this [Area3D]'s overlap list. That is correct, not a bug,
## but it makes a layout rule: never place a rack's footprint inside a zone's
## volume, or stock will appear to vanish from the zone the moment it is
## stored.

enum Kind { IN, OUT }

@export var kind: Kind = Kind.IN

@onready var _marker: MeshInstance3D = $Marker
@onready var _label: Label3D = $Label


func _ready() -> void:
	add_to_group("goods_zone")

	var tint: Color
	var text: String
	if kind == Kind.OUT:
		tint = Color(0.90, 0.65, 0.25)
		text = "GOODS OUT"
	else:
		tint = Color(0.35, 0.75, 0.45)
		text = "GOODS IN"

	# A fresh material per instance, exactly as player.gd colours its capsule
	# from peer_id — one scene serving both kinds, with the difference
	# derived locally and never networked.
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(tint.r, tint.g, tint.b, 0.18)
	_marker.material_override = material
	_label.text = text


## Crates currently inside the zone's volume. Whichever peer calls this reads
## its own [Area3D]'s overlap list, so a client's answer can lag the host's by
## a frame or two near a boundary — see warning 2 above.
func contents() -> Array[Crate]:
	var found: Array[Crate] = []
	for body in get_overlapping_bodies():
		var crate := body as Crate
		if crate != null:
			found.append(crate)
	return found


func count() -> int:
	return contents().size()
