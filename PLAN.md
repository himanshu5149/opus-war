GAME ANALYSIS — CINDERHORN ATLAS
────────────────────────────────
Fantasy + pillars : A lone field surveyor cataloguing a living volcano. Pillars:
                    PATIENCE, READING, EVIDENCE.
Narrative goal    : Complete the Cinderhorn Atlas — gather 3 evidence sets from the
                    armored six-legged Cinderhorn and carry them back to the Forge
                    Anvil at the basin's north rim before the camp burns down.
Signature mechanic: READ THE CHARGE. The Cinderhorn paws, its horn vents flare and a
                    glowing amber charge-lane decal paints the ground ~1.0s before it
                    rushes. Dodge-roll OUT of the lane inside that window and it
                    over-runs, crashing and STAGGERING for 3s with its carapace vents
                    open — only then does the field cutter bite deep (and only then
                    does it shed an evidence shard). Hitting a non-staggered creature
                    does chip damage and gets you gored.
MDA hypothesis    : telegraph + commitment-dodge -> player stops mashing and starts
                    watching the ground -> the feeling of being a careful naturalist
                    in danger, not a warrior.
30-second arc     : 0-5s amber basin, camp light, compass arrow to the first trace.
                    5-12s read a trace site (E) -> first lead + salt herb. 12-20s the
                    Cinderhorn roars in, first telegraph, first dodge. 20-30s first
                    stagger, first cutter hit, first evidence shard, weather shifts.
Core loop         : explore basin -> read traces / gather salt herbs -> bait a charge ->
                    dodge -> counterattack the staggered vents -> bank evidence at camp ->
                    defend camp -> return the full Atlas to the forge.
Dimension         : 3D  (CharacterBody3D, Camera3D, WorldEnvironment, .glb props).
                    3D LOOK FLOOR is binding: BG_SKY ProceduralSkyMaterial gradient,
                    fog matched to horizon, FILMIC tonemap, glow, key DirectionalLight
                    with shadows + cool sky-ambient fill, per-material roughness,
                    emissive pickups, tiling salt-crust albedo on the basin floor,
                    Kenney .glb models instanced for camp/forge/rocks/trees/crates.
Perspective       : behind-player third person, orbit camera, mouse-look / touch-drag.
PRIMARY genre     : top-down-action (subordinated to 3rd person: telegraph-read combat)
Secondary traits  : roguelike — ONE sentence: the run has an escalating 3-phase
                    structure and a single exclusive field upgrade chosen after the
                    first evidence set. Nothing else from roguelike.

STAGE PLAN
  Phase 1 "Amber Survey"  : clear weather, slow Cinderhorn, wide telegraph window.
                            Player learns trace reading + the dodge.
  Phase 2 "Amber Haze"    : thick dust fog rolls in, visibility drops, creature +25%
                            speed, shorter telegraph, ember motes drift. Camp begins
                            taking ember damage; salt herbs -> potions matter.
  Phase 3 "Ember Rain"    : sky goes red, falling embers damage you outside camp
                            shelter, creature enrages (double charge). Wow beat:
                            the Cinderhorn's carapace cracks and glows molten.
  Finale                  : with 3/3 evidence, the forge at the north rim lights up a
                            beacon pillar; reach it -> ATLAS COMPLETE victory card.

ENTITY ROSTER
  Player  : amber-coated surveyor, teal visor + teal lantern (only teal in the world),
            tall thin silhouette, field cutter glows teal on swing.
  Cinderhorn : six-legged armored beast. Low wide wedge silhouette, charcoal plates,
            molten orange seams, two forward horns. Reads instantly vs the player.
  Trace sites : half-buried salt cairns w/ an emissive amber mote column.
  Salt herbs : small emissive pale-green crystal clusters on the crust.
  Camp     : Kenney house + crates + firepit, teal lantern ring = safe shelter.
  Forge    : Kenney castle on the north rim, dormant until 3/3 evidence.
  Scatter  : Kenney rocks (scaled/rotated/tinted per instance) + ash trees.
PALETTE : bg sky amber #E8A75A->#6E2E1F, basin crust #C8A06A, rim rock #4A3A33,
          player teal #3FE0C8 (accent, interactables only), hazard molten #FF6A1E,
          HUD ink #15100D on #E9C892.
UI THEME: letterpress field-journal. One StyleBoxFlat helper for EVERY button
          (normal/hover/pressed/disabled). Sizes 52/26/15. No emoji.
Fail / win : fail = health 0 or camp integrity 0. win = 3 evidence sets delivered to
          the lit forge.
Wow beat (<=3 min): Phase 3 transition — sky turns to ember rain, the Cinderhorn's
          plates crack molten and it double-charges.
Riskiest feature : the charge telegraph + dodge + stagger window. Prototype FIRST.
