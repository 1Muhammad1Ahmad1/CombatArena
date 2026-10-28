# CombatArena project status

**State: map graphics overhaul done on all three maps; realistic weapons and bot soldiers; exported and verified (2026-10-28).**
Build: `build\CombatArena.exe` (single file, 514 MB). Godot 4.7.2, Forward+.

## Distant rendering quality (2026-10-28)
Washed-out distance was the fog; grain and jagged thin roof members were aliasing. Fog removed indoors and halved
outdoors; Medium now uses TAA (Settings > TEMPORAL AA to switch back to FXAA). Measured: far contrast +10 to +65 %,
shimmer in motion -34 to -65 %; Medium 1280x720 now 87 / 82 / 126 FPS (Warehouse / Urban / Desert), was 98 / 98 / 148.
Details and tables in TEST_RESULTS.md.

## Timed matches and results screen (2026-10-28)
- Every match lasts **10 minutes of active play**: countdown `10:00` -> `00:00` at the top of the HUD (turns red in
  the last 30 s). It starts when gameplay begins, stops while paused, and resets on every new match.
- The player is **`allied_warrior`** in the HUD scoreboard, kill feed and results. Bots draw three unique call-signs
  per match from a 30-name pool (never `allied_warrior`); a bot keeps its name through deaths and respawns.
- At `00:00` the match ends exactly once: the world freezes (no combat, damage, scoring or respawning), the mouse is
  released and a results screen shows rank, name, kills and deaths for all four participants, ranked by kills then
  fewest deaths, with shared ranks for full ties (1, 1, 3) and a WINNER / JOINT WINNERS banner. `allied_warrior` is
  highlighted. Results come from a frozen snapshot. Buttons: PLAY AGAIN (same map, fresh scores, new 10:00 clock,
  new bot names), MAIN MENU, QUIT.
- Code: `match.gd` (timer, `end_match`, `rank_rows`, `pick_bot_names`, guards), `results_screen.gd`, HUD clock,
  `main.test_match_duration` (test-only short duration; normal matches always use 600 s).

## Map overhaul (2026-10-28)
Layouts, collision volumes, cover positions, spawns and patrol points are unchanged on every map, so gameplay,
navigation and sightlines are as before (152 automated checks pass). What changed is the visible geometry:

| Map | Before | Now |
|---|---|---|
| Urban | Textured boxes with flat window panes | Buildings assembled from the Poly Haven modular apartment/factory facade kits: real window and door openings with frames, cornices, crowns, plinths, corner piers, balconies with railings, dark interiors behind the glass. Three styles: residential, commercial (ground-floor shops with roller shutters, some with graffiti), industrial. Per-building wall tints. Raised paving with kerbs, manholes, utility poles with sagging cables, fire escapes, wall AC units, security lights, bins, rubble heaps and debris, boarded windows, water-stain decals, skyline blocks beyond the walls. |
| Warehouse | Box walls, slab roof, square posts, solid railings | Brick factory-kit walls with tall windows, steel roof trusses and purlins under corrugated panels, I-beam columns with base plates, see-through grating catwalks on beams, open post-and-rail railings, overhead crane on a runway, duct runs, pipe runs, shelving, pallets with boxes, generator, compressor, carts, fluorescent fittings, floor stains. |
| Desert | Flat sand box, sphere dunes, cone mountains, box rocks, box HESCO/sandbags | Generated terrain (flat play field, sand ridge over the berms, dunes, rocky hills), scanned Namaqualand cliffs and boulders (the rocks you take cover behind are now scanned boulders over the old collision boxes), segmented HESCO cells with posts, stacked rounded sandbags (all maps), braced watchtowers with corrugated roofs, sand-plastered kit buildings, trucks with wheels, dry bushes, branches, dead quiver trees, haze. |

Rendering: PBR everywhere (scanned CC0 textures), neutral colour grading (saturation 1.0, AgX), lighter haze with
aerial perspective, SSAO (Medium+), SSR (Epic), SSIL + volumetric fog (Epic), occlusion culling with a box occluder per
building, per-side facade batches with near/far LOD switching, prop triangle caps, opaque single-sided facade
materials, anisotropic filtering. High now uses FSR 2 upscaling (67 %) with temporal AA instead of MSAA, which also
removes shimmer on thin wires and railings.

Glitches found and fixed this round: pale opaque rectangles from an unsuitable asphalt decal (removed), a bright
streak from a tyre-track decal (removed), sun glare on paving (lower specular), whole-map MultiMesh batches that could
never be culled (now per building side), transparent double-sided window glass (opaque, single-sided), 86k-triangle
props (capped), wall-decal projection direction, sandbags that looked like floating discs (new bag mesh).

## Bot soldiers (2026-10-28)
| Before | Now | Source / licence |
|---|---|---|
| Quaternius toon soldiers (big heads, bright colours) | VIPER: Swat (blue uniform, helmet, plate carrier); RAVEN: Gas Mask (black gear, respirator); HAZARD: Swat Guy (grey camo, tactical vest) | Mixamo (Adobe), royalty-free in games |
| Toon animations | Mixamo Rifle Idle, Rifle Walk, Rifle Run, Firing Rifle, Hit Reaction, Death From The Front | Mixamo |
| (no clip) walk/run while firing | Built in code: legs from Walk/Run, spine and arms from Firing Rifle, tiled so the loop is seamless | code |
| Toy blue gun in the bots' hands | The textured AK-74M (same model as the player's), placed every frame with the grip in the right hand and the barrel through the left hand | Cransh, CC-BY 4.0 |

The firing clip stands bladed, so the rifle pointed ~45° off the bot's facing; the body is turned to compensate,
and the rifle now points within 7° of where the bot aims (measured). Character textures were reduced from 4096 to 1024.

## Weapons and environment (2026-10-27)
| Before | Now | Source / licence |
|---|---|---|
| Capsule "tube" arms + box hands | Rigged, textured FPS arms (sleeves, tactical gloves, articulated fingers) | "FPS AK-74m animations" by Cransh, **CC-BY 4.0** |
| Low-poly toy AK viewmodel | Textured AK-74M (receiver, magazine, sights, trigger, PBR metal/polymer) | same pack |
| Low-poly toy sniper viewmodel | Remington-700-style rifle with wood stock, PBR textures, working bolt | "Free Sniper Rifle M700" by Stein Games, **CC0** |
| (no scope on the M700) | Riflescope: eyepiece, tube, turrets, objective bell, rings, tinted lenses | **Modelled in code** (revolved profile), not an external asset |
| Generated noise textures | Scanned PBR sets: concrete, floor concrete, corrugated steel, planks, bricks, plaster, asphalt, sand, steel plate | ambientCG, **CC0** |
| Toy-style crates, barrels, barriers, cars, lamps, clutter | Military crate stacks, steel barrels, concrete road barriers, tarp-covered cars, street lamps, hanging industrial lamps, propane tanks, utility boxes, hydrants, tyres, jerrycans, plastic crates | Poly Haven, **CC0** |
| Toy shipping containers | Corrugated-steel PBR containers with corner posts | ambientCG texture on a box |

## First-person animations (all verified in captured frames, `screenshots/v3_after/viewmodel`)
| Animation | AK-74M | M700 sniper |
|---|---|---|
| Idle (slowed while aiming) | authored clip | authored clip (AK rig, rifle swapped) |
| Walk / sprint | authored clips | authored clips |
| Fire + recoil recovery | authored Shot clip, plus camera recoil and a procedural kick | same + **bolt cycles** (lift, pull, push, lock) |
| Reload | authored Reload: the **magazine is pulled and reseated** (timed to the 1.9 s gameplay reload) | same clip; the M700 box magazine follows the rig's magazine bone |
| Empty reload | authored Reload_full (2.5 s) | same |
| Equip / Q switch | authored Draw clip, fitted to the 0.45 s switch | same |
| Aim down sights | rig moves so the **rear notch and front post sit exactly on screen centre** (where shots go) | scope axis moves to centre, then the scope overlay takes over |

Both hands come from the same IK-animated rig, so the right hand stays on the pistol grip and the left on the foregrip in
every clip. The rig is anchored to the camera and scaled down around it (same image, so it can't clip into walls).

## Unchanged and still working
Free-for-all with 3 bots (all now realistic soldiers), all three maps, Q / C / Z / R / scope / sprint / jump, menus, settings, pause, damage, respawns,
scoreboard. 152 automated checks pass in the exported exe.

## Remaining placeholders and limitations
- **Performance:** a later Medium pass cut GPU time to 9.2-9.8 ms (Warehouse) and 9.6-10.1 ms (Urban), i.e. about
  100 FPS GPU-side, but FPS could not be re-measured because the laptop CPU was throttled to 31 % clock that session.
  Last full measurement before that pass: Medium 720p 78.5 (Warehouse) / 83.6 (Urban) / 123 (Desert) FPS against a
  90 target; High 1080p 51.9 / 55.5 / 63.8 against 60. Epic is not playable on a P2000. See TEST_RESULTS.md.
- **Exe size 514 MB** (was 273 MB) from the PBR textures of ~30 new models; still under the 1 GB limit.
- **Some cover is still simple geometry:** shipping containers (corrugated PBR boxes), dumpsters, the office walls in
  the warehouse, the desert ruins and fuel tanks. No abandoned military vehicles or tanks (no free realistic model
  without a login); the cars are tarp-covered.
- **No building interiors you can enter** in Urban; the windows show a dark interior.
- **Bots have no reload or crouch animation** (they never crouched; reloads happen with the idle/fire pose). (Left hand
  now sits on the handguard via two-bone IK; headshots use the live neck-bone height.)
- **Bot rifle in carry poses** (idle, walk, hit) is held across the body as Mixamo authored it; only firing clips aim forward.
- **The scope** is modelled in code, not a downloaded asset (the only CC0 scope found is a .blend file, and you chose not to
  install Blender).
- **The sniper reuses the AK's arm animations.** The hands, grip and recoil look right, but the reload is an AK-style
  magazine change, not a bolt-action top-load. The M700's magazine is small and mostly hidden inside the stock.
- **Buildings, walls, rocks, HESCO and sandbags** are still boxes. They now have scanned or generated PBR materials, but no modelled detail.
- **Performance:** High at 1080p averages 58–81 FPS (Warehouse and Urban just under 60). Medium at 720p averages 110–156 FPS.
  One-off frame spikes of up to ~63 ms still occur.
