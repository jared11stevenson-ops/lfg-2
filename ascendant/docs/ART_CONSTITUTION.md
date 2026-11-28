# Art constitution (derived from the code as it is, not aspirations)
Source: art/ink.gd, art/creature_art.gd, art/structure_art.gd, art/shaders/terrain.gdshader.

## Identity
"Illuminated bestiary": painterly dome-shaded forms with hand-inked outlines on watercolour ground. Muted, dusk-toned, slightly cool shadows.

## Shape language
- All art is built from Ink primitives: radial domes (3 rings, ellipse), spine strips with per-point width, tapered capsule limbs, Catmull-Rom smoothed spines. No hard polygons except fins/tails.
- Bodies are soft ovals and tapered strips; structures are domes, stacked rings and radial lines (webs, thorn rings).

## Lighting rule (Ink.shade)
- Single light from upper-left/above (L = (-0.42,-0.62,0.66) normalised), applied in world space via the heading `rot`.
- Hue-shifted: shadow = base darkened 42% blended 22% toward violet (0.16,0.12,0.34); light = base lightened 22% blended 14% toward warm yellow (1,0.92,0.62). Rim darkening (pow(1-nz, 2.5) * 0.55) rounds silhouettes.
- A soft cast shadow is drawn under each creature.

## Palette gamut (Ink.palette)
- Saturation 0.18-0.62, value 0.34-0.78 from heritable loci; belly = lighter, desaturated hue+0.03; accent snaps to harmony angles (+-0.08, +-0.42, 0.5); eye = complement at S 0.55 V 0.9. Genetics cannot leave this gamut.
- Ruins desaturate 55% toward grey and darken 10% (structure_art ruin factor).

## Outline rule
- Ink colour = base darkened 62% blended 45% toward (0.09,0.07,0.15). Width from `_line_w(phenotype)`, scaled with body. Outlines drawn after fills, in order of body parts. Known violation: prop-layer boulders draw outlines offset from fills.

## Animation rules (creature_art)
- Pose inputs: heading, time, gait phase, speed 0..1, turn -1..1.
- Body undulation sin(5.2t - phase) scaled by position along the spine; breathing +-2% width; tail sway with turn lean; alternating limb phase with stride swing and lift scaled by speed; swimmers use wide tail profile and fin strokes.
- Anatomy drives animation (limb length/count, swim, burrow claws), never a shared humanoid rig.

## Terrain / UI
- Terrain: data texture (elevation, moisture, water, temperature) -> bilinear sampled, fbm-mottled painterly ground, inked coast with foam.
- UI: cream parchment panels, ink-navy text, gold corner studs, drop shadow. Known violations: clipped labels (ui_new.png).

## Enforcement
Assets enter via assets/manifest quarantine; approval needs rendered evidence and per-category evidence text (tools/asset_gate.gd).
