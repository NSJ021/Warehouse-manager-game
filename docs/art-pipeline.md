# Art pipeline

How art gets made and how it reaches Godot. Design intent lives in [§9 of the GDD](GDD.md); this document is the *production* side.

Nothing here is a locked decision. Where a call becomes load-bearing it graduates to an ADR.

---

## 1. The one rule

**Grid-critical geometry is hand-modelled. Everything organic can be generated.**

> ⚠ **The grid module is 0.5 m** (ADR 16), and grid-critical assets are modelled to it
> *exactly* — not approximately, not "close enough to snap". A crate is 0.5 m cubed; a
> Medium is 1.0 × 0.5; a Large is 1.0 × 1.0; a four-slot rack bay is 2.0 m wide. Getting
> this wrong is not a visual problem, it is a snapping problem, and it is discovered late.

The grid-storage ADR makes exact dimensions load-bearing — a rack slot that is 3% off does not snap. Generative tools are indifferent to precise measurement, which is fine for a person and fatal for a shelf.

| Asset | How | Why |
|---|---|---|
| **The crate** | Hand-modelled | One mesh, swappable label decals, the most reused asset in the game. Must be exactly grid-sized. It is a box; it takes ten minutes. |
| Racks, shelving, dock doors, mezzanine | Hand-modelled | Modular, must tile, dimension-critical |
| Walls, floors, structure | Hand-modelled / CSG greybox | Same |
| **Player character** | Generated, then cleaned | Organic, characterful, benefits from auto-rigging |
| NPC clients, drivers | Generated, then cleaned | As above |
| Clutter props, bins, pallets, signage | Either | Generate for variety where nothing snaps to it |

---

## 2. Route

```
Generator (text/image → 3D)  →  Blender (clean up, retopo, scale, rig check)  →  GLB  →  Godot
                                ↑
                        hand-modelled assets enter here
```

**Blender is the hub, not Godot.** These tools generally ship direct engine plugins — Blender, Godot, Unity, Unreal — and going straight into the engine is tempting. Don't. Most of this game's geometry is hand-modelled in Blender anyway, so routing generated assets through it too gives one export path, one place to fix topology, and one place to verify scale. A direct engine plugin creates a second parallel pipeline for a handful of assets, and split pipelines drift.

Export **GLB** to Godot. Most generators also offer FBX, OBJ, BLEND and USDZ.

---

## 3. Tooling

### Generative 3D — candidate, not adopted

A text-to-3D / image-to-3D generator with built-in retopology, rigging and animation. Specific tool evaluated and shortlisted; the choice is recorded in the local development notes rather than here, since nothing is committed yet.

**What makes one of these viable rather than a toy:**

- **Retopology with a real polygon budget** — a target poly count with a triangles-or-quads option. Without it you get a 50k-triangle blob and an afternoon of manual cleanup. Target **~3–6k quads** for this style.
- **Auto-rigging with animation presets** — matches the GDD's "simple rig, a walk cycle with too much bounce".
- **The art direction dodges the known weaknesses.** The consistently reported failure modes across these tools are distorted faces, extra fingers and broken proportions. The GDD's derpy humanoids have **mitten hands with no fingers and minimal facial detail** — there is nothing there to get wrong. Keeping the style disciplined is therefore a production decision, not only an aesthetic one.

**⚠ Licensing — read before generating anything**

| Tier | Typical rights |
|---|---|
| Free | Often **CC BY 4.0** — commercial use permitted **but requires attributing the tool in the shipped game** |
| Paid | Full ownership, no attribution, full rights to distribute and sell |

**Licences attach at generation time.** Subscribing later does not retroactively clean assets already generated on a free tier. Anything that might ship must be generated on a paid plan — **including throwaway placeholders**, because placeholders have a habit of shipping.

**Practical plan:** one paid month is enough to generate and rig the character set, then cancel.

### Blender

Required regardless of what else is used. Retopology, scale correction, rig verification, and every hand-modelled asset.

---

## 4. Style constraints that affect production

Drawn from the winners in the comparable set (see [§11 of the GDD](GDD.md)):

- **Flat shading is the style.** When decimating a generated mesh, preserve hard edges. Smooth-shading low-poly geometry turns crisp facets into lumps and loses the whole look.
- **Silhouette first.** Most people will first see this game as a 400-pixel-wide clip on a phone. If a prop is not readable as a shape at that size, detail will not save it.
- **Reject baked lighting.** No baked shadows or ambient occlusion in generated textures. Lighting is a gameplay system here — hard overhead fluorescents, aisles as bright lanes separated by shadow — and baked shadows fight it.
- **Near-zero texture work.** Flat colour, minimal maps. The savings go into audio, which is doing the heavy lifting.
- **Ask for T-pose or A-pose.** Required for auto-rigging or retargeting. Generators default to dynamic poses, which are useless for a rig.

### Player colours

Four players must be distinguishable at a glance. **The hi-vis vest carries the player colour.**

Generate **one** character with the vest on its own material slot and tint it at runtime — `scripts/player/player.gd` already does this via `PLAYER_COLOURS` and `material_override`:

| Player | Colour |
|---|---|
| 1 | `#e8b64c` amber |
| 2 | `#4ca8e8` blue |
| 3 | `#6cc24a` green |
| 4 | `#e05c5c` red |

Never four separate models — four times the work and four times the drift.

---

## 5. Character generation prompts

Tool-agnostic. Tuned to the GDD's derpy-humanoid brief, and deliberately shaped so the generator's known weak spots — faces, fingers, proportions — have nothing to grip.

### Third-person body (what other players see)

```
Low-poly stylised warehouse worker, full body, T-pose, symmetrical, game-ready
character. Chunky exaggerated cartoon proportions: broad blocky torso, short
stubby legs, oversized mitten hands with no separate fingers, simplified rounded
head with minimal facial detail and no visible mouth. Wearing an open
high-visibility safety vest over a plain t-shirt, loose work trousers, and heavy
steel-toe work boots. Flat-shaded solid colour surfaces, no texture detail, no
logos, no text, no patterns. Strong readable silhouette. Muted grey and beige
clothing with the safety vest as the only saturated colour. Even neutral
lighting, no baked shadows, no ground plane or base, plain background.
```

### First-person arms (what you see)

A separate asset — first-person games almost never reuse the body mesh for the viewmodel.

```
Low-poly stylised first-person viewmodel arms only, from mid-forearm to hand,
pair of arms, palms forward. Oversized mitten hands with no separate fingers,
thick rounded forms. Rolled-up sleeve at the forearm cuff. Flat-shaded solid
colours, no texture detail. Even neutral lighting, no baked shadows, plain
background, no body, no head.
```

### Negative prompt

```
realistic, photorealistic, high detail, detailed face, individual fingers,
skin pores, fabric weave, dramatic lighting, baked shadows, ambient occlusion,
base, plinth, pedestal, weapon, text, logo
```

### Acceptance checklist

Reject and regenerate rather than fixing by hand — it is faster:

- [ ] T-pose or A-pose, symmetrical
- [ ] Hands are **mittens**, no separate fingers *(the most common failure)*
- [ ] No baked shadows or ambient occlusion in the texture
- [ ] Hi-vis vest on its **own material slot** for runtime tinting
- [ ] Decimates to ~3–6k quads with hard edges preserved
- [ ] Silhouette still readable at 400px wide

---

## 6. Generated-asset register

The Steam store page will carry an AI-content disclosure at launch. That is already decided and is not in question.

**Every generated asset gets logged here as it is made.** This is trivial to maintain from asset one and miserable to reconstruct at launch.

| Asset | Date | Notes |
|---|---|---|
| *(none yet)* | | |
