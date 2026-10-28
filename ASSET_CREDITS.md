# Third-party assets

## First-person arms and AK-74M (CC-BY 4.0, credit required)
This work is based on **"FPS AK-74m animations"**
(https://sketchfab.com/3d-models/fps-ak-74m-animations-94be8385c402474cacd39bc096c6ca14)
by **Cransh** (https://sketchfab.com/ccransh), licensed under **CC-BY-4.0** (http://creativecommons.org/licenses/by/4.0/).
- Downloaded unmodified from the author-licensed copy redistributed at
  https://github.com/Ayush-Mohanty/FPS-Arms-3D/tree/main/Models/fps_ak-74m_animations (includes the original `license.txt`).
- Stored in `assets/fps_ak74m/`. Used: rigged textured arms (gloves and sleeves), AK-74M mesh, and the animations
  Idle, Walk, Run, Shot, Reload, Reload_full and Draw.
- Changes made in code: re-anchored to the game camera, scaled, timing adjusted, AK hidden for the sniper variant.
- The credit is also shown on the main menu.

## Sniper rifle: "Free Sniper Rifle M700 CC0" (CC0 1.0)
- Author: Stein Games, https://stein-indie.itch.io/m700 (downloaded through the page's free download flow, 2026-10-27).
- File `Sniper_R700_Free_CC0.zip`. Used: `SKM_SniperR700.fbx` and its 2048 px colour, normal and mask textures
  (the mask was converted to Godot ORM channel order). `assets/m700/license.txt`: "The license is CC0 1.0".
- The riflescope is **not** from this pack. It is modelled in code (`weapons.gd: build_scope()`) from a revolved profile.

## Props: Poly Haven (CC0)
https://polyhaven.com (all models CC0). 1K glTF downloads via https://api.polyhaven.com, stored in `assets/polyhaven/`:
Barrel_01, Barrel_02, concrete_road_barrier, concrete_road_barrier_02, wooden_crate_02, old_military_crate,
wooden_military_crate, old_tyre, metal_jerrycan, covered_car, street_lamp_01, hanging_industrial_lamp,
propane_tank, utility_box_01, fire_hydrant, ammo_box, plastic_crate_01.

## Surface textures: ambientCG (CC0)
https://ambientcg.com (all CC0). 1K JPG sets (colour, OpenGL normal, roughness, AO, metalness where present),
stored in `assets/ambientcg/`:
Concrete034, Concrete044B, CorrugatedSteel007A, PaintedMetal009 (downloaded, not used), Planks023A, Ground054, Ground037,
Asphalt025C, Bricks076C, Plaster001, MetalPlates006.

## Bot soldiers and animations: Mixamo (Adobe)
https://www.mixamo.com, downloaded 2026-10-28 with the owner's Adobe account. Adobe allows Mixamo characters and
animations to be used royalty-free in games; the raw FBX files must not be redistributed on their own (they are only
packed inside the exported game). They are left out of the public GitHub repository (see README for how to download them). Stored in `assets/mixamo/` (textures reduced from 4096 to 1024).
| Bot | Mixamo character |
|---|---|
| VIPER | Swat |
| RAVEN | Gas Mask |
| HAZARD | Swat Guy |

Clips: Rifle Idle, Rifle Walk (In Place), Rifle Run (In Place), Firing Rifle, Hit Reaction, Death From The Front.
Walk/run-while-firing are built in code from these clips (legs from the walk/run, upper body from Firing Rifle).
The bots carry the AK-74M from Cransh's CC-BY 4.0 pack (see above).

The Quaternius Toon Shooter Game Kit (CC0) characters are no longer used and are excluded from the export.

## Map overhaul assets (2026-10-28)
Full list with URLs, licences, sizes and download method: `assets/downloads/MANIFEST.csv`.
Stored in `assets/downloads/<map>/<models|materials|decals>/<id>/`.

**Poly Haven models (CC0, no attribution required)**, https://polyhaven.com/a/<id>: modular_urban_apartments_facade, modular_fire_escape, modular_electricity_poles, exterior_aircon_unit, rollershutter_window_01, security_light, metal_trash_can, water_manhole_cover, modular_factory_facade, modular_airduct_rectangular_01, overhead_crane, steel_frame_shelves_02, worn_metal_rack, portable_generator, old_military_compressor, hand_truck, industrial_storage_cart, mounted_fluorescent_lights, cardboard_box_01, barrel_03, namaqualand_boulder_02, namaqualand_boulder_04, namaqualand_boulder_05, namaqualand_boulders_01, namaqualand_cliff_01, namaqualand_cliff_02, namaqualand_rocks_01, dead_quiver_trunk, wild_rooibos_bush, dry_branches_medium_01.
Fetched with the Poly Haven public API (started before the Neat Download Manager instruction arrived).
Downloaded but not used in the game (excluded from the export): modular_electric_cables, modular_metal_gutter, rollershutter_door, street_lamp_02, modular_airduct_circular_01, modular_industrial_pipes_01, steel_frame_shelves_01, namaqualand_stones_01, modular_chainlink_fence, large_iron_gate.

**ambientCG materials and decals (CC0, no attribution required)**, https://ambientcg.com/view?id=<id>: Leaking003, Leaking008, PavingStones138, Ground108, Concrete044D, Ground080, Rock061, Gravel040, Metal041B, MetalWalkway014.
All 13 ambientCG sets were downloaded through **Neat Download Manager 1.4.24** via its Chrome extension
(NDM records #4-#16, all "Complete"; ZIPs verified with a CRC test and size match before extraction).
Downloaded but not used: AsphaltDamage001, TireTracks001, Leaking012A (their opacity maps did not suit decals).

Generated in code for the overhaul: roof trusses, I-beams, purlins, railings, pallets, pipes, HESCO cells,
sandbag geometry, debris chunks, overhead cables, balconies, kerbs, desert terrain.

## Everything else
Generated in code: building and terrain geometry, sandbag / HESCO / rock / camo / painted-metal textures,
the scope, effects, UI, and all audio.
