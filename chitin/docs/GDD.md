# CHITIN: Molt of the Last Hive — Game Design Document

Engine: Godot 4.7 (Mobile renderer, GDScript). Target: iOS/Android, landscape, 60 fps on mid-range 2022 devices, offline-first.
Status key: **[BUILT]** exists in this repo and is tested · **[SLICE]** partially built · **[DESIGN]** specified, not built.

---
## 1. Premise
The **Molt** was a chemical tide that rewrote the human genome. Within a generation, cities were colonised by what people became: chitinous, many-limbed, scent-speaking. Words died; **pheromone** is the only language left. The old world's ruins are now **Districts**, each a living ecosystem of mutated humans ("the Kin"), true insects grown huge, and the **Regents** — hive-minds that were once whole cities' worth of people.

You are not a hero. You are a **Lineage**: a bloodline of larvae that the Regent's Chrysalis keeps rebuilding. Each body you wear lives one *instar* and then molts. What you ate, who you spared and how you smelled all become heritable.

Tone: grim, organic, eerie-beautiful. Bioluminescent decay, not gore. Mystery: *why does the Chrysalis keep remaking you — and what is the Regent protecting?*

## 2. Pillars
1. **You are your own ecosystem.** Past lives persist as Echoes; your hunting thins species; your scent lingers on the map.
2. **Speak with chemistry.** No dialogue menus. Diplomacy is composing a scent chord and reading what comes back.
3. **Bodies are builds, builds are heredity.** Genes are diploid, dominant/recessive, mutate under stress, and cross with your own past selves.
4. **Every death is a design input**, never a fail-state. Dying changes *what you become*.

## 3. THE CORE LOOP — "The Molt Cycle"  [BUILT in slice]
| Phase | Duration | What happens |
|---|---|---|
| **Instar** | 5–7 min | Explore a district (3D, twin-stick). Hunt, parley, forage. Eat genes (latent), bank Bile, accumulate Stress. A **Tide** (roach swarm) rises at 70% of the clock. |
| **Chrysalis (molt)** | – | Voluntary at a pod (safe, keep all Bile) or forced by death (lose half carried Bile). |
| **Echo birth** | instant | Your body becomes an Echo stamped with your *play style* (aggression vs kinship) — a **Kin-Echo ally** or a **Revenant hunter**. |
| **World turn** | instant | Ecology steps forward (longer life = more steps). Overhunted species have shrunk; scent you laid has diffused. |
| **Pupation** | 1–2 min | Rebuild: per slot pick two alleles from *self / eaten / Echo mate*; Stress rolls mutations; Bile locks slots. Preview stats. Emerge. |

What is new here: the three couplings — **(a)** play style → Echo disposition → the next life's world; **(b)** a real predator–prey simulation that your kills perturb; **(c)** a wordless scent language that is both combat *and* diplomacy and must be *learned per species*.

## 4. Systems

### 4.1 Genome  [BUILT — `core/genome.gd`, `core/gene_db.gd`]
- Six slots: Head, Thorax, Abdomen, Limbs, Wings, Skin. Two alleles per slot (`{id, mut}`).
- Expression: higher *effective dominance* (`dom × (1+0.2·mut) + 0.01·rarity`) is expressed; the other is **recessive** and travels silently — it can return when crossed.
- Mutation levels 0–3 scale a gene's modifiers (+35% per level) and dominance.
- Crossing: one random allele per parent per slot; each inherited allele mutates with probability `0.06 + 0.30·stress` (cap 0.5). Mutation either deepens (60%) or swaps to a random gene of that slot.
- 30 genes shipped (6 baselines + 24). 9 grant active abilities. Stats: HP, speed, armor, damage, sense, scent, stamina, stealth, regen.
- **[DESIGN]** Chimeric expression (codominance for 'twin' genes), epigenetic marks from diet, a 7th *Ovipositor* slot for Hive-building.

### 4.2 Scent language  [BUILT — `core/scent.gd`]
- Chord = (Fear, Kin, Hunger, Regent) ∈ [0,1]⁴. Each species has a hidden **want** chord.
- Quality = similarity × power factor. Outcomes: **Enrage / Ignore / Calm / Recruit / Flee**. Pure terror (Fear>0.8, Kin<0.4) routs fearful species. Elites (Regent) can be calmed but never fully recruited — *except via the Queen Path (§7)*.
- **Learning**: Antennae *reveal* a noisy version of the want; noise falls with scent power. Players triangulate by observing reactions (Enraged vs Calmed). Species wants are fixed per save so knowledge carries across lives — the game's *knowledge* progression.
- Scent Burst (gland ability) parleys every creature in radius.
- Mobile UX: four vertical sliders + EMIT (toggle panel). Presets slots **[DESIGN]**.

### 4.3 Ecology  [BUILT — `core/ecology.gd`]
- Logistic growth, predation and starvation per species (8 species, predator/prey graph in `species_db.gd`). Bounded and tested for 200 steps.
- Player kills apply `apply_kill` (overhunting reduces future spawn counts → scarcity of the genes you rely on).
- 24×24 **pheromone grid** (4 channels) with decay + diffusion. Deposits from your chords. **[DESIGN]** wildlife and Echoes read it for tracking and territory, so a "smell of the Regent" can lure or scare an entire district.

### 4.4 Echoes  [BUILT — `core/echo.gd`]
- `aggression = kills/(kills+recruits+calms+1)`, `kinship = (2·recruits+calms)/(kills+2·recruits+calms+1)`.
- Kin-Echo: fights for you, mate option at pupation. Revenant: hunts you, drops its expressed genes (even mutated ones) — a way to *recover* a great build you threw away.
- Up to 10 stored; 3 manifest per life. **[DESIGN]** Echo "memorial" at the Chrysalis; Echoes can be fed to the Hive for Lineage XP.

### 4.5 Combat  [BUILT/SLICE]
- Twin-stick action: BITE (cone, stamina), 3 ability buttons from genes, dash/i-frames, snare/rooting, AoE, projectiles.
- Creature roles: prey (flee), pack (swarm), ambush (strikes at 6m), hunter, drone, **Regent** (telegraphed 6 m slam, 1.1 s wind-up).
- Stress: damage taken raises it; high stress = more mutation = riskier but more *interesting* heredity. Deliberate risk-taking is a strategy.
- **[DESIGN]** Weak-point plates, status effects (acid, silk, spores), co-op revive, difficulty modifiers ("Famine", "Plague").

### 4.6 Survival  [BUILT]
Hunger drains (~9 min to empty); kills restore it; starvation bleeds HP. Ichor (stamina) gates every action.

### 4.7 Districts  [BUILT — `core/district_gen.gd`]
Deterministic ruined grids from a seed: towers with bioluminescent bands, Chrysalis pod, nests per species (Regent in the north). **[DESIGN]** 6 biomes: *Drowned Metro, Glass Orchard, Cathedral of Hives, Rust Foundry, Bone Reservoir, Sunless Canopy* — each with its own species mix, hazard (acid rain, spore storms, collapse) and Regent.

## 5. Meta-progression  [DESIGN]
**The Hive** (persistent base, reached from the Chrysalis): spend Bile on *Brood Chambers*:
- **Gene Vault** — bank a latent gene permanently (cap grows).
- **Scent Archive** — stores discovered species wants (no relearning after wipe).
- **Nursery** — extra Echo mate slots, raised mutation floor, reroll mutations.
- **Larder** — start each life fed.
Lineage Rank unlocks district tiers. No pay-to-win; see §10.

## 6. Narrative structure  [DESIGN]
Act I *Hatch* (tutorial district) → Act II *Seven Regents* (each district) → Act III *The First Molt*. Story told through **memory scents**: a creature of a given want-chord releases a human memory ("a lullaby", "a bus route") as a short 2D painted vignette. The Regents were people who refused to leave; the final choice is **Slay**, **Absorb** or **Free** (the Queen Path).

## 7. The Queen Path  [DESIGN]
A Kin-heavy lineage can *recruit* a Regent (needs exact Regent chord + max Kin-Echoes alive). Your lineage becomes a Hive-mind: Echoes persist across districts, and the world becomes cooperative instead of predatory. The aggressive path yields raw power; the kin path yields permanence. Both are endings.

## 8. Art direction
- Bioluminescent noir: deep teal fog, amber chrysalis light, magenta/cyan spore accents. Silhouette-first creatures (readable on 6" screens).
- **Slice**: procedural primitive insects (`world/insect_mesh.gd`) so every genome is visible. **Production**: Blender-authored low-poly (≤4k tris hero, ≤1.5k wildlife), baked vertex-colour + a single 512² atlas, skeletal rigs with insect gait IK; swap-in is one function.
- UI: translucent chitin-glass panels, large touch targets (≥56 px), colour-blind-safe scent channels (also encoded by icon, not only hue).

## 9. Audio  [DESIGN]
Stridulation-based score (stridulating strings, hive drones); each Regent has a leitmotif that *changes with your lineage's scent*. Spatial creature calls; scent emission has a soft chemical "shimmer". 6 dB ducking during parley.

## 10. Business & ethics
Premium or free-with-cosmetic-DLC. No energy timers, no loot boxes, no gene purchases. Rewarded ads: none.

## 11. Technical
- GDScript, data-driven (GeneDB / SpeciesDB). Deterministic seeded generation; save = JSON (`user://lineage.json`, versioned `v`).
- Mobile renderer, glow + fog, ≤6 dynamic lights, ≤46 AI bodies, procedural meshes (draw-call batching planned via MultiMesh for ruins).
- Performance budget: 16.6 ms; AI scan staggered at 4 Hz; ecology off the frame loop (runs only at molts).
- Tests: `godot --headless --path chitin --script tests/run_tests.gd` (382 checks); smoke: `godot --headless --path chitin -- --smoke`.
- **[DESIGN]** Cloud-save + opt-in async "Echo exchange": players trade Echoes (genome + scent), never live PvP.

## 12. Roadmap
| Milestone | Scope |
|---|---|
| M1 (this repo) | Genome, scent, ecology, echoes, pupation, one district, touch controls, tests |
| M2 | Hive base, Gene Vault, tutorial, audio, 2nd & 3rd biome, Blender asset pass |
| M3 | Remaining biomes + Regents, narrative memories, Queen Path |
| M4 | Polish, accessibility, device-farm perf, soft launch |

## 13. Honest status of this build
Verified: 382 headless unit checks; scripted life (parley → kill → molt → pupation → gen 2) passes; one rendered frame inspected. **Not verified**: real-device touch feel, performance on phones, game balance, audio (none), any content beyond one district. Visuals are procedural placeholders.
