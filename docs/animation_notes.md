# Creature animation study (Level 1 creatures)

## Research findings (what existing tools/data say) - 2026-11-27
1. **Tripo has a production auto-rig + animation service** (the same tool that generated the models). Official docs (developers.tripo3d.com, API base https://openapi.tripo3d.com/v3):
   - `POST /v3/animations/rig-check` -> `{riggable, rig_type}` where rig_type is one of biped, quadruped, hexapod, octopod, avian, serpentine, aquatic. Free (0 credits in the example).
   - `POST /v3/animations/rig` with `input` (a generation task_id, uploaded file_token or public URL; GLB/FBX/OBJ/STL up to 150 MB), `model` ("v2.5-20260210" for non-humanoids, "v3.0-20260909" newest), `rig_type`, `out_format` glb|fbx. About 25 credits in the docs example.
   - `POST /v3/animations/retarget` with `input` = the RIG task id and `animation`/`animations` (max 5). Non-biped presets: `preset:quadruped:walk`, `preset:hexapod:walk`, `preset:octopod:walk`, `preset:serpentine:march`, `preset:aquatic:march`. No avian preset is listed. About 10 credits per animation. Options: `animate_in_place`, `export_with_geometry`, `out_format`.
   - Poll `GET /v3/tasks/{id}`; result `output.model_url` is a rigged/animated GLB or FBX.
   - Not stated anywhere: required pose/T-pose.
2. **UniRig** (VAST-AI-Research/UniRig, SIGGRAPH 2025, by Tripo's parent): open-source autoregressive skeleton + skinning-weight prediction for arbitrary meshes. Needs a GPU; checkpoint availability should be checked on the repo.
3. **Blender Rigify** ships Cat, Wolf, Horse, Basic Quadruped meta-rigs (IK legs, spine, tail). Automatic weights (heat diffusion) are the standard skinning method; our distance-falloff weights are a stopgap.
4. **Gait data**: Muybridge's Animal Locomotion plates (public domain, archive.org / Project Gutenberg) are the primary reference. Cat lateral-sequence footfall order is right hind, right front, left hind, left front (EurekAlert, citing Muybridge). Animation tutorials (Animation Mentor, Autodesk 3ds Max quadruped walk, Toon Boom, Animschool) agree on key poses contact, down, passing, up for each leg, hips and chest acting as two offset bouncing balls, a 24-frame example cycle, and that dog/wolf contact-to-passing is only about 2 frames at speed.
5. Sources gave NO gait mechanics for manul or bat-eared fox specifically (only build and behaviour), and nothing on hoatzin head-bobbing.


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

## What was actually built (td/tools/blender/rigkit.py, rig_tickindle.py, rig_others.py)
| Need | Technique (source) | Where |
|---|---|---|
| Skeleton to skin | Hand-fit armature per creature in normalized model space (anatomy from the notes above); controls separate from deform bones | rig_*.py BONES |
| Skin weights | Blender automatic weights (heat diffusion, `parent_set(type='ARMATURE_AUTO')`) on a watertight voxel-remeshed proxy, then Data Transfer to the real mesh, nearest-vertex fill, limit 4 influences, normalise. Direct heat diffusion on the raw fur-shell mesh failed (5% to 100% of vertices unweighted); the proxy fixes it. | rigkit.bind_heat |
| Legs | Blender IK constraint, chain of 2, pole targets, pole angle auto-calibrated so knees/elbows bend the anatomically right way; foot controls live in world space so feet plant while the body bobs | rigkit.add_ik_leg / calibrate_pole |
| Gait | Footfall order: cat lateral sequence RH, RF, LH, LF (Muybridge via EurekAlert); fox trot as diagonal pairs; biped alternation for the bird. Stance linear / swing eased arc; two bounces per cycle; hips and chest counter-rotate ("two bouncing balls"); walk cycle length = ground travel per cycle so feet do not skate (anim_meta walk_units) | rig_*.py, enemy.gd |
| Secondary motion | Second-order dynamics (t3ssel8r, "Giving Personality to Procedural Animations"; k1=z/(pi f), k2=1/(2 pi f)^2, k3=r z/(2 pi f); r<0 anticipation, r>1 overshoot), chained along tails, ears, crest, steam, lantern, watch | rigkit.SOD |
| Attacks | Key poses (anticipation, coil, strike, impact squash, settle) with slow-in/slow-out; the shot is released on the strike frame (anim_meta strike) | rig_*.py base() |
| Type payoff | Per-type effects at baked anchors: Ember/Forge flame cone, Tide/Spirit lantern flare + ripples, Verdant/Venom spore cloud + steam, Umbra/Gale shadow crescent | attack_fx.gd |

Not used: Tripo's rig/retarget API (credential did not authenticate here), UniRig (needs a GPU), Rigify (not needed once IK + heat weights worked).
