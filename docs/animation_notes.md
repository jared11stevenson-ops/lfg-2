# Creature animation study (Level 1 creatures)

Sources found: Smithsonian/WWF/ADW (manul build), ADW/Britannica (bat-eared fox ears, foraging), Science Advances 2019 + ADW (hoatzin), open.edu + Fish & Lauder (sirenian swimming), Wikipedia/StudioBinder (12 principles).
Gait mechanics were NOT in those sources. The footfall timings below are standard quadruped biomechanics from general knowledge; treat them as design choices, not citations.

## Principles we apply
Anticipation (wind-up before every attack), squash and stretch (volume-preserving), arcs, follow-through and overlapping action (tail/ears/lantern lag the body by a fraction of a cycle), secondary motion, slow-in/slow-out, weight shift, appeal (exaggerate the personality).

## Tickindle: Pallas's cat (manul)
- Stocky, short stumpy legs, very low stance, dense long fur, thick banded tail, small low-set ears. Ambush predator: creeps low, then pounces.
- Walk: lateral-sequence (LH, LF, RH, RF at quarter-cycle offsets), short stride, body sways side to side, head carried low and steady (counter-rotates against the shoulders). Heavy: small bounce, big weight shift.
- Idle: slow breathing in the ribs, ear flicks, tail tip twitch (flame lags).
- Ember/Forge attack: low crouch (anticipation) -> pounce lunge, chest heaves, tail flame flares, ember burst at the mouth, forge sparks.

## Dugloom: dugong
- Swims by up/down caudal oscillation of a horizontal fluke; flippers steer, brake and stabilise. Heavy, slow, buoyant, whiskered snout.
- Move: S-wave travels from head to tail (phase lag), fluke trails; flippers paddle out of phase; lantern lags like a pendulum.
- Tide/Spirit attack: inhale (body swells), flipper sweep, lantern flares and a ripple ring of water/spirit light bursts out.

## Hutzin: hoatzin (as a teapot-hut bird)
- Big crop, small head on a long neck, spiky crest, clumsy; adult wing claws; stands/perches; chicks climb with claws.
- Walk: bipedal waddle, head thrusts forward and holds while the body catches up (bird head-bob is a general bird behaviour), crest and steam lag.
- Verdant/Venom attack: rear back (chest/crop swells), snap forward, spit; green-violet spore puff from the beak and a steam burst from the spout.

## Shuckit: bat-eared fox + Black Shuck
- Slight, slender legs, huge mobile ears (ear flaps rotate to listen), long bushy tail; slow deliberate foraging walk, fast agile escape; trot is diagonal pairs (LF+RH, RF+LH).
- Idle: ear swivel, tail wisp.
- Umbra/Gale attack: crouch, lunge-bite with a shadow smear and a crescent of wind.

## Rig approach
Two-bone legs (upper, lower) solved with 2-bone IK so feet plant on the ground and knees/elbows bend the right way; skin weights from distance falloff, smoothed along the mesh surface.
