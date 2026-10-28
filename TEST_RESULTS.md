# CombatArena test results

Date: 2026-10-28 (timed matches + results screen; map graphics overhaul) · Godot 4.7.2 · Dell Precision 7530, i7-8850H, 16 GB, Quadro P2000 4 GB

## Summary
| Run | Result |
|---|---|
| Automated suite, editor binary | **178 PASS, 0 FAIL, 1 NOT TESTED** (152 existing + 25 timed-match + 1 TAA-setting check) |
| Same suite inside the exported `build\CombatArena.exe` | **178 PASS, 0 FAIL, 1 NOT TESTED** |
| Timed match smoke test, windowed exe (7 s test match on Urban, HUD clock + results screen captured) | **PASS** (`screenshots/v8_match_exe`) |
| All three maps load, navmesh bakes, bots path and fight (FFA), every stance, both weapons | **PASS** (suite) |
| Before/after captures from identical viewpoints (4 per map) | `screenshots/v5_baseline`, `screenshots/v5_after`, `screenshots/v5_<map>_before_after.jpg` |

The "Graphics preset applies" test was updated: High now uses FSR 2 upscaling (67 %) instead of 2x MSAA (see below).

## Measured performance (exported exe, VSync off, 10 s of live 3-bot combat, average FPS)
| Map | Low 1280x720 | Medium 1280x720 | High 1920x1080 | Epic 1920x1080 |
|---|---|---|---|---|
| Industrial Warehouse | 139.7 | **78.5** | **51.9** | 26.9 |
| Urban Warfare | 141.4 | **83.6** | **55.5** | 29.2 |
| Desert Outpost | 208.4 | **123.0** | **63.8** | 37.7 |

Before the overhaul (same benchmark): Medium 112.0 / 125.1 / 177.3, High 64.5 / 54.7 / 88.0.
Low/Medium/Epic numbers come from the first export of this round; only the High preset changed afterwards and was
re-measured. The benchmark spot is the player's random spawn, so runs vary by a few FPS.

Targets: Medium 90+ is met on Desert only (Warehouse 78.5, Urban 83.6). High 60 is met on Desert and nearly on Urban
(55.5). Epic (native 1080p, MSAA 4x, SSR, SSIL, volumetric fog, full facade shadows) is a showcase preset, not playable
on this GPU. Profiling details are in BUILD_LOG.md.

## Medium optimisation pass (same day, later)
Changes: glow off on Medium; warehouse floor and roof underside as UV-mapped planes (no triplanar sampling over half
the screen); size-based triangle budgets for scanned props; small props (< 1.2 m) skip the sun-shadow pass; warehouse
fill lights 16 m -> 11 m range; hall facades switch to their far LOD at 18 m (indoors). Geometry and layouts unchanged.

Measured as GPU render time per frame at Medium 1280x720 (in-run A/B and live benchmark, editor build):
| View | Before | After | GPU-limited frame rate after |
|---|---|---|---|
| Warehouse, live combat | 12.1-12.9 ms | **9.2-9.8 ms** | ~102-109 FPS |
| Urban, street canyon (heaviest view) | 11.0-11.6 ms | **9.6-10.1 ms** | ~99-104 FPS |

**Frame rates could not be re-measured this time:** during this session the laptop's CPU dropped to 31 % of its base
clock (~0.8 GHz, Windows "% Processor Performance" = 31, constant; on AC power, Balanced plan). As a control, the
previous, unchanged exe that measured 83.6 FPS on Urban Medium earlier the same day measured 56.6 FPS with render CPU
time 10.5 ms (was 3.1 ms). FPS numbers taken in that state would not be comparable, so the table above reports GPU
time, which is what limited Medium before. Re-run the benchmark once the CPU is back to full clock (see NEXT_STEPS.md).
Tests after the pass: 152 PASS / 0 FAIL / 1 NOT TESTED in editor and exported exe.

## Distant rendering quality pass (2026-10-28)
Hardware: Dell Precision 7530, i7-8850H, Quadro P2000 4 GB (display through the Intel UHD 630, rendering on the
P2000), 16 GB RAM. Default configuration: **Medium, 1280x720 window, internal resolution 1280x720 (scale 1.0)**.
The 60 FPS seen in normal play is the **VSync cap** (VSync on, 60 Hz panel); benchmarks run with VSync off.

**Image-quality probe** (`tests/quality_probe.gd` + `tools/quality_metrics.py`): fixed camera per map, one setting
changed at a time; far-region RMS contrast (higher = less washed out), mid-region grain (|Laplacian|) and shimmer
(high-frequency change between consecutive frames of a slow pan, after alignment). Warehouse findings:
| Config | Far contrast | Grain | Shimmer |
|---|---|---|---|
| Old default (FXAA, fog 0.012) | 25.8 | 9.65 | 1.71 |
| Fog off | 42.3 | 15.6 | 2.82 |
| No AA / MSAA 2x / SMAA | 26.8 / 26.5 / 25.9 | 13.6 / 12.0 / 11.1 | 2.35 / 2.22 / 2.03 |
| TAA | 26.0 | 6.6 | 0.72 |
| 16x anisotropic, -0.58 mip bias, SSAO off / higher quality | no measurable change | | |

Causes: washed-out distance = fog (+ a little from the additive light shafts); grain and jagged thin roof members =
geometric/shader aliasing that FXAA barely reduces and MSAA/SMAA do not fix. Ruled out: mipmaps/mip bias, anisotropic
filtering, SSAO noise, sharpening (none is applied at Medium; FSR 2 on High applies its own bias, no measurable effect).

Fixes: warehouse fog off (indoors), urban fog 0.0045 -> 0.0025, desert 0.0045 -> 0.003, aerial perspective 0.2 -> 0.1;
**TAA is the Medium (and Epic) anti-aliasing**, with a new Settings toggle "TEMPORAL AA" (off = FXAA). New defaults
measured at the same cameras:
| Map | Far contrast | Shimmer | Grain |
|---|---|---|---|
| Warehouse | 25.8 -> 42.6 | 1.71 -> 1.12 | 9.65 -> 11.2 (more real detail visible without fog) |
| Urban | 29.3 -> 36.4 | 2.37 -> 0.82 | 12.4 -> 9.7 |
| Desert | 40.3 -> 44.4 | 1.59 -> 0.65 | 9.7 -> 6.9 |
TAA ghosting check: a bot running across the view at 4.6 m/s, 7 m away, shows no visible trail (`screenshots/probe/ghost`).
Comparison sheets: `screenshots/v7_distance_before_after.jpg`, `screenshots/v7_warehouse_roof_zoom.jpg`.

**Performance** - repeatable route benchmark (`--bench-path`: 24 s camera route per map, sweeping turns, 3 bots fighting),
Medium 1280x720 native, VSync off, CPU at full clock (verified), editor build, same session:
| Map | Before avg / 1 % low / p99 | After avg / 1 % low / p99 | GPU ms before -> after |
|---|---|---|---|
| Warehouse | 97.9 / 59.9 / 13.7 ms | 87.2 / 55.7 / 15.0 ms | 9.71 -> 10.95 |
| Urban | 97.6 / 67.1 / 12.4 ms | 81.5 / 56.1 / 14.4 ms | 9.74 -> 11.75 |
| Desert | 147.8 / 104.7 / 9.2 ms | 125.8 / 84.0 / 10.6 ms | 6.27 -> 7.45 |
Exported exe, after: Warehouse 87.5 / 57.0, Urban 81.8 / 57.6, Desert 121.2 / 55.1. VRAM used ~0.9 GB (textures ~0.8 GB).
Tradeoff: TAA costs 1.2-2.0 ms GPU (11-17 % FPS); the default stays above the 70-80 FPS target on all maps. With
TEMPORAL AA off the cost goes away (fog removal in the warehouse also saved ~0.8 ms). Earlier in the session the CPU was
throttled to 31 % clock; those runs (in BUILD_LOG.md) were not used for this comparison.

## Not tested / manual checks
| Test | Status | Notes |
|---|---|---|
| Results QUIT button closes the game | NOT TESTED (pressing) | Verified connected to `get_tree().quit()`; pressing it would end the run. |
| Full 10-minute match in real time | NOT TESTED | The 600 s duration is checked (starts at 10:00, counts down, pauses); the expiry flow is verified with a 4 s test duration on all three maps. |
| EXIT GAME quits | NOT TESTED | Wired to `get_tree().quit()`; pressing it would end the automated run. |
| Hands-on play with a physical mouse/keyboard | NOT TESTED | Input simulated through Godot input actions. |
| Sound output | NOT TESTED | Headless runs use a dummy audio driver. |

## Full automated results (exported exe run)

| Category | Test | Result | Evidence |
|---|---|---|---|
| MENUS | Main menu shows START GAME / SETTINGS / EXIT GAME | **PASS** | buttons: START GAME / SETTINGS / EXIT GAME |
| MENUS | Start Game opens map selection | **PASS** | current menu script: res://scripts/ui/map_select.gd |
| MENUS | Map selection lists exactly 3 maps | **PASS** | 3 map cards |
| MENUS | Back returns to main menu | **PASS** | current menu script: res://scripts/ui/main_menu.gd |
| MENUS | Settings opens from main menu | **PASS** | settings overlay present: true |
| MENUS | Settings change applies and persists to disk | **PASS** | sensitivity runtime=1.75 saved=1.75 (C:/Users/HC/AppData/Roaming/Godot/app_userdata/CombatArena/settings.cfg) |
| MENUS | Graphics preset applies | **PASS** | quality=2 scaling_mode=2 scale=0.67 (High = FSR 2 at 67 %) |
| MENUS | Settings BACK closes overlay | **PASS** | overlay present: false |
| MENUS | Exit Game quits application | **NOT TESTED** | EXIT GAME is connected to SceneTree.quit(); not pressed here because it would end the test process |
| MAPS | INDUSTRIAL WAREHOUSE loads | **PASS** | match started: true |
| MAPS | INDUSTRIAL WAREHOUSE navigation mesh baked and synced | **PASS** | 502 navmesh polygons, map ready=true |
| MAPS | INDUSTRIAL WAREHOUSE spawn locations valid (on navmesh, no geometry overlap) | **PASS** | 11 bot + 4 player spawns valid |
| MAPS | INDUSTRIAL WAREHOUSE navigation connects all spawns/patrol points (no inaccessible bot positions) | **PASS** | 23 targets reachable from (28.0, 0.5, -2.0) |
| BOTS | INDUSTRIAL WAREHOUSE exactly 3 active bot slots | **PASS** | active=3 nodes=3 |
| BOTS | INDUSTRIAL WAREHOUSE bots move and navigate | **PASS** | 3/3 bots moved > 1.5 m in 4 s |
| WEAPONS | INDUSTRIAL WAREHOUSE assault rifle fires and damages bot | **PASS** | bot HP 92 -> 71, AR ammo 30 -> 29 |
| COMBAT | INDUSTRIAL WAREHOUSE bot health reaches 0 and bot dies | **PASS** | alive=false after 5 more shots, death events +1, kills +1 |
| COMBAT | INDUSTRIAL WAREHOUSE no repeated bot death events | **PASS** | death events +1 after extra damage on corpse |
| HUD | INDUSTRIAL WAREHOUSE kill counter updates | **PASS** | label: 'KILLS  1      DEATHS  0' |
| BOTS | INDUSTRIAL WAREHOUSE bot respawns after 3 seconds | **PASS** | alive at ~2.9 s: false, alive at ~3.3 s: true, active=3 |
| WEAPONS | INDUSTRIAL WAREHOUSE Q switches to sniper and back | **PASS** | after 1st Q cur=true, after 2nd Q cur=0 |
| WEAPONS | INDUSTRIAL WAREHOUSE ammo persists across switches | **PASS** | AR ammo 25 -> 25 |
| WEAPONS | INDUSTRIAL WAREHOUSE switching cannot bypass fire rate | **PASS** | shot1=true, shot ~1.1 s later blocked=true, shot after 1.3 s fired=true |
| WEAPONS | INDUSTRIAL WAREHOUSE sniper scope works | **PASS** | scoped=true fov=14.0 overlay=true |
| WEAPONS | INDUSTRIAL WAREHOUSE sniper fires and headshot kills | **PASS** | bot HP 60 -> 0 (95 dmg x2.5 head) |
| WEAPONS | INDUSTRIAL WAREHOUSE reload refills magazine from reserve | **PASS** | started=true ammo=30 reserve 180 -> 153 |
| HUD | INDUSTRIAL WAREHOUSE HUD shows real health and ammo | **PASS** | hp label '100' (hp 100), ammo label '30' (ammo 30) |
| BOTS | INDUSTRIAL WAREHOUSE bot detects player | **PASS** | bot state=COMBAT awareness=1.00 |
| BOTS | INDUSTRIAL WAREHOUSE bot aims and fires | **PASS** | 14 shots fired |
| COMBAT | INDUSTRIAL WAREHOUSE bot bullets reduce player health | **PASS** | player HP 100 -> 84, 2 hits / 14 shots |
| HUD | INDUSTRIAL WAREHOUSE damage indicator shown | **PASS** | 2 active indicators |
| COMBAT | INDUSTRIAL WAREHOUSE player death counted exactly once | **PASS** | deaths 0 -> 1, alive=false |
| HUD | INDUSTRIAL WAREHOUSE death counter updates | **PASS** | label: 'KILLS  2      DEATHS  1' |
| COMBAT | INDUSTRIAL WAREHOUSE player respawns with 100 HP | **PASS** | alive=true hp=100 |
| FFA | INDUSTRIAL WAREHOUSE bots cannot damage themselves | **PASS** | self hit result=false hp 100 -> 100 |
| FFA | INDUSTRIAL WAREHOUSE bots acquire each other as targets | **PASS** | first acquisition after 0.48 s (A target=none, B target=OUTLAW) |
| FFA | INDUSTRIAL WAREHOUSE bots fire at and damage each other | **PASS** | shots A=17 B=28, bot-on-bot damage events=22 |
| FFA | INDUSTRIAL WAREHOUSE bot-vs-bot kill credited to the real attacker | **PASS** | after 4.9 s: JACKAL killed OUTLAW (killer kills 0 -> 1, victim deaths +1, player kills unchanged 2) |
| FFA | INDUSTRIAL WAREHOUSE killer drops the dead target | **PASS** | killer target now: none |
| FFA | INDUSTRIAL WAREHOUSE bot killed by a bot respawns after 3 s, still 3 slots | **PASS** | victim alive=true active=2 nodes=3 |
| FFA | INDUSTRIAL WAREHOUSE observed match: bots fight each other with the player hidden | **PASS** | 60 s: 7 bot-vs-bot kills, 7 bot deaths, player hit 0 times [], scoreboard COBALT 3/1, JACKAL 3/4, OUTLAW 3/5, allied_warrior 2/1 |
| FFA | INDUSTRIAL WAREHOUSE no self-targeting and no lingering dead targets | **PASS** | self-target frames=0, frames aiming at a corpse >0.2 s=0 |
| FFA | INDUSTRIAL WAREHOUSE target selection is stable | **PASS** | 3 live-to-live target switches across 3 bots in 60 s |
| MOVEMENT | INDUSTRIAL WAREHOUSE WASD movement | **PASS** | W 3.35 m, S -2.21 m, D 2.23 m, A -2.21 m (along facing axes) |
| MOVEMENT | INDUSTRIAL WAREHOUSE sprint is faster than walking | **PASS** | walk 5.59 m/s, sprint 8.59 m/s |
| MOVEMENT | INDUSTRIAL WAREHOUSE jump | **PASS** | peak height 1.51 m |
| MOVEMENT | INDUSTRIAL WAREHOUSE C crouches (1.2 m capsule, lowered camera) | **PASS** | stance=1 shape=CapsuleShape3D height=1.20 eye=1.08 |
| MOVEMENT | INDUSTRIAL WAREHOUSE crouched: slower movement and shooting works | **PASS** | crouch speed 2.99 m/s, shot fired=true |
| MOVEMENT | INDUSTRIAL WAREHOUSE C again stands up | **PASS** | stance=0 |
| MOVEMENT | INDUSTRIAL WAREHOUSE Z goes prone (box collision, camera near floor) | **PASS** | stance=2 shape=BoxShape3D eye=0.36 |
| MOVEMENT | INDUSTRIAL WAREHOUSE prone crawling works (slow) | **PASS** | crawled 1.10 m in 1 s |
| MOVEMENT | INDUSTRIAL WAREHOUSE cannot sprint or jump while prone | **PASS** | speed with sprint held 1.10 m/s, height change 0.00 |
| MOVEMENT | INDUSTRIAL WAREHOUSE prone: shoot, switch, reload and scope all work | **PASS** | fire=true switch=true reload=true/true scope=true |
| MOVEMENT | INDUSTRIAL WAREHOUSE stand-up clearance check (blocked under 0.85 m ceiling, allowed after) | **PASS** | stayed prone on Z=true, on C=true, stance after ceiling removed=0 |
| BOTS | INDUSTRIAL WAREHOUSE still exactly 3 bots after deaths/respawns (no duplicates) | **PASS** | active=3 nodes=3 bot deaths=10 |
| MAPS | URBAN WARFARE loads | **PASS** | match started: true |
| MAPS | URBAN WARFARE navigation mesh baked and synced | **PASS** | 651 navmesh polygons, map ready=true |
| MAPS | URBAN WARFARE spawn locations valid (on navmesh, no geometry overlap) | **PASS** | 11 bot + 4 player spawns valid |
| MAPS | URBAN WARFARE navigation connects all spawns/patrol points (no inaccessible bot positions) | **PASS** | 24 targets reachable from (-30.0, 0.5, -0.25) |
| BOTS | URBAN WARFARE exactly 3 active bot slots | **PASS** | active=3 nodes=3 |
| BOTS | URBAN WARFARE bots move and navigate | **PASS** | 3/3 bots moved > 1.5 m in 4 s |
| WEAPONS | URBAN WARFARE assault rifle fires and damages bot | **PASS** | bot HP 100 -> 79, AR ammo 30 -> 29 |
| COMBAT | URBAN WARFARE bot health reaches 0 and bot dies | **PASS** | alive=false after 5 more shots, death events +1, kills +1 |
| COMBAT | URBAN WARFARE no repeated bot death events | **PASS** | death events +1 after extra damage on corpse |
| HUD | URBAN WARFARE kill counter updates | **PASS** | label: 'KILLS  1      DEATHS  0' |
| BOTS | URBAN WARFARE bot respawns after 3 seconds | **PASS** | alive at ~2.9 s: false, alive at ~3.3 s: true, active=3 |
| WEAPONS | URBAN WARFARE Q switches to sniper and back | **PASS** | after 1st Q cur=true, after 2nd Q cur=0 |
| WEAPONS | URBAN WARFARE ammo persists across switches | **PASS** | AR ammo 25 -> 25 |
| WEAPONS | URBAN WARFARE switching cannot bypass fire rate | **PASS** | shot1=true, shot ~1.1 s later blocked=true, shot after 1.3 s fired=true |
| WEAPONS | URBAN WARFARE sniper scope works | **PASS** | scoped=true fov=14.0 overlay=true |
| WEAPONS | URBAN WARFARE sniper fires and headshot kills | **PASS** | bot HP 100 -> 0 (95 dmg x2.5 head) |
| WEAPONS | URBAN WARFARE reload refills magazine from reserve | **PASS** | started=true ammo=30 reserve 180 -> 153 |
| HUD | URBAN WARFARE HUD shows real health and ammo | **PASS** | hp label '100' (hp 100), ammo label '30' (ammo 30) |
| BOTS | URBAN WARFARE bot detects player | **PASS** | bot state=COMBAT awareness=1.00 |
| BOTS | URBAN WARFARE bot aims and fires | **PASS** | 10 shots fired |
| COMBAT | URBAN WARFARE bot bullets reduce player health | **PASS** | player HP 100 -> 84, 5 hits / 10 shots |
| HUD | URBAN WARFARE damage indicator shown | **PASS** | 2 active indicators |
| COMBAT | URBAN WARFARE player death counted exactly once | **PASS** | deaths 0 -> 1, alive=false |
| HUD | URBAN WARFARE death counter updates | **PASS** | label: 'KILLS  2      DEATHS  1' |
| COMBAT | URBAN WARFARE player respawns with 100 HP | **PASS** | alive=true hp=100 |
| FFA | URBAN WARFARE bots cannot damage themselves | **PASS** | self hit result=false hp 100 -> 100 |
| FFA | URBAN WARFARE bots acquire each other as targets | **PASS** | first acquisition after 0.48 s (A target=none, B target=GHOST) |
| FFA | URBAN WARFARE bots fire at and damage each other | **PASS** | shots A=16 B=16, bot-on-bot damage events=22 |
| FFA | URBAN WARFARE bot-vs-bot kill credited to the real attacker | **PASS** | after 6.3 s: BLAZE killed GHOST (killer kills 0 -> 1, victim deaths +1, player kills unchanged 2) |
| FFA | URBAN WARFARE killer drops the dead target | **PASS** | killer target now: none |
| FFA | URBAN WARFARE bot killed by a bot respawns after 3 s, still 3 slots | **PASS** | victim alive=true active=2 nodes=3 |
| FFA | URBAN WARFARE observed match: bots fight each other with the player hidden | **PASS** | 60 s: 3 bot-vs-bot kills, 3 bot deaths, player hit 0 times [], scoreboard BLAZE 3/2, allied_warrior 2/1, HUNTER 2/1, GHOST 0/3 |
| FFA | URBAN WARFARE no self-targeting and no lingering dead targets | **PASS** | self-target frames=0, frames aiming at a corpse >0.2 s=0 |
| FFA | URBAN WARFARE target selection is stable | **PASS** | 5 live-to-live target switches across 3 bots in 60 s |
| MOVEMENT | URBAN WARFARE WASD movement | **PASS** | W 3.35 m, S -2.21 m, D 2.23 m, A -2.21 m (along facing axes) |
| MOVEMENT | URBAN WARFARE sprint is faster than walking | **PASS** | walk 5.59 m/s, sprint 8.59 m/s |
| MOVEMENT | URBAN WARFARE jump | **PASS** | peak height 1.51 m |
| MOVEMENT | URBAN WARFARE C crouches (1.2 m capsule, lowered camera) | **PASS** | stance=1 shape=CapsuleShape3D height=1.20 eye=1.08 |
| MOVEMENT | URBAN WARFARE crouched: slower movement and shooting works | **PASS** | crouch speed 2.99 m/s, shot fired=true |
| MOVEMENT | URBAN WARFARE C again stands up | **PASS** | stance=0 |
| MOVEMENT | URBAN WARFARE Z goes prone (box collision, camera near floor) | **PASS** | stance=2 shape=BoxShape3D eye=0.36 |
| MOVEMENT | URBAN WARFARE prone crawling works (slow) | **PASS** | crawled 1.10 m in 1 s |
| MOVEMENT | URBAN WARFARE cannot sprint or jump while prone | **PASS** | speed with sprint held 1.10 m/s, height change 0.00 |
| MOVEMENT | URBAN WARFARE prone: shoot, switch, reload and scope all work | **PASS** | fire=true switch=true reload=true/true scope=true |
| MOVEMENT | URBAN WARFARE stand-up clearance check (blocked under 0.85 m ceiling, allowed after) | **PASS** | stayed prone on Z=true, on C=true, stance after ceiling removed=0 |
| BOTS | URBAN WARFARE still exactly 3 bots after deaths/respawns (no duplicates) | **PASS** | active=3 nodes=3 bot deaths=6 |
| MAPS | DESERT OUTPOST loads | **PASS** | match started: true |
| MAPS | DESERT OUTPOST navigation mesh baked and synced | **PASS** | 810 navmesh polygons, map ready=true |
| MAPS | DESERT OUTPOST spawn locations valid (on navmesh, no geometry overlap) | **PASS** | 12 bot + 4 player spawns valid |
| MAPS | DESERT OUTPOST navigation connects all spawns/patrol points (no inaccessible bot positions) | **PASS** | 25 targets reachable from (0.0, 0.5, 30.0) |
| BOTS | DESERT OUTPOST exactly 3 active bot slots | **PASS** | active=3 nodes=3 |
| BOTS | DESERT OUTPOST bots move and navigate | **PASS** | 3/3 bots moved > 1.5 m in 4 s |
| WEAPONS | DESERT OUTPOST assault rifle fires and damages bot | **PASS** | bot HP 100 -> 79, AR ammo 30 -> 29 |
| COMBAT | DESERT OUTPOST bot health reaches 0 and bot dies | **PASS** | alive=false after 5 more shots, death events +1, kills +1 |
| COMBAT | DESERT OUTPOST no repeated bot death events | **PASS** | death events +1 after extra damage on corpse |
| HUD | DESERT OUTPOST kill counter updates | **PASS** | label: 'KILLS  1      DEATHS  0' |
| BOTS | DESERT OUTPOST bot respawns after 3 seconds | **PASS** | alive at ~2.9 s: false, alive at ~3.3 s: true, active=3 |
| WEAPONS | DESERT OUTPOST Q switches to sniper and back | **PASS** | after 1st Q cur=true, after 2nd Q cur=0 |
| WEAPONS | DESERT OUTPOST ammo persists across switches | **PASS** | AR ammo 25 -> 25 |
| WEAPONS | DESERT OUTPOST switching cannot bypass fire rate | **PASS** | shot1=true, shot ~1.1 s later blocked=true, shot after 1.3 s fired=true |
| WEAPONS | DESERT OUTPOST sniper scope works | **PASS** | scoped=true fov=14.0 overlay=true |
| WEAPONS | DESERT OUTPOST sniper fires and headshot kills | **PASS** | bot HP 100 -> 0 (95 dmg x2.5 head) |
| WEAPONS | DESERT OUTPOST reload refills magazine from reserve | **PASS** | started=true ammo=30 reserve 180 -> 153 |
| HUD | DESERT OUTPOST HUD shows real health and ammo | **PASS** | hp label '100' (hp 100), ammo label '30' (ammo 30) |
| BOTS | DESERT OUTPOST bot detects player | **PASS** | bot state=COMBAT awareness=1.00 |
| BOTS | DESERT OUTPOST bot aims and fires | **PASS** | 8 shots fired |
| COMBAT | DESERT OUTPOST bot bullets reduce player health | **PASS** | player HP 100 -> 84, 2 hits / 8 shots |
| HUD | DESERT OUTPOST damage indicator shown | **PASS** | 2 active indicators |
| COMBAT | DESERT OUTPOST player death counted exactly once | **PASS** | deaths 0 -> 1, alive=false |
| HUD | DESERT OUTPOST death counter updates | **PASS** | label: 'KILLS  2      DEATHS  1' |
| COMBAT | DESERT OUTPOST player respawns with 100 HP | **PASS** | alive=true hp=100 |
| FFA | DESERT OUTPOST bots cannot damage themselves | **PASS** | self hit result=false hp 100 -> 100 |
| FFA | DESERT OUTPOST bots acquire each other as targets | **PASS** | first acquisition after 0.48 s (A target=JACKAL, B target=none) |
| FFA | DESERT OUTPOST bots fire at and damage each other | **PASS** | shots A=36 B=34, bot-on-bot damage events=23 |
| FFA | DESERT OUTPOST bot-vs-bot kill credited to the real attacker | **PASS** | after 12.5 s: VORTEX killed JACKAL (killer kills 0 -> 1, victim deaths +1, player kills unchanged 2) |
| FFA | DESERT OUTPOST killer drops the dead target | **PASS** | killer target now: none |
| FFA | DESERT OUTPOST bot killed by a bot respawns after 3 s, still 3 slots | **PASS** | victim alive=true active=2 nodes=3 |
| FFA | DESERT OUTPOST observed match: bots fight each other with the player hidden | **PASS** | 60 s: 4 bot-vs-bot kills, 4 bot deaths, player hit 0 times [], scoreboard SABLE 3/1, VORTEX 3/3, allied_warrior 2/1, JACKAL 0/3 |
| FFA | DESERT OUTPOST no self-targeting and no lingering dead targets | **PASS** | self-target frames=0, frames aiming at a corpse >0.2 s=0 |
| FFA | DESERT OUTPOST target selection is stable | **PASS** | 4 live-to-live target switches across 3 bots in 60 s |
| MOVEMENT | DESERT OUTPOST WASD movement | **PASS** | W 3.35 m, S -2.21 m, D 2.23 m, A -2.21 m (along facing axes) |
| MOVEMENT | DESERT OUTPOST sprint is faster than walking | **PASS** | walk 5.59 m/s, sprint 8.59 m/s |
| MOVEMENT | DESERT OUTPOST jump | **PASS** | peak height 1.51 m |
| MOVEMENT | DESERT OUTPOST C crouches (1.2 m capsule, lowered camera) | **PASS** | stance=1 shape=CapsuleShape3D height=1.20 eye=1.08 |
| MOVEMENT | DESERT OUTPOST crouched: slower movement and shooting works | **PASS** | crouch speed 2.99 m/s, shot fired=true |
| MOVEMENT | DESERT OUTPOST C again stands up | **PASS** | stance=0 |
| MOVEMENT | DESERT OUTPOST Z goes prone (box collision, camera near floor) | **PASS** | stance=2 shape=BoxShape3D eye=0.36 |
| MOVEMENT | DESERT OUTPOST prone crawling works (slow) | **PASS** | crawled 1.10 m in 1 s |
| MOVEMENT | DESERT OUTPOST cannot sprint or jump while prone | **PASS** | speed with sprint held 1.10 m/s, height change 0.00 |
| MOVEMENT | DESERT OUTPOST prone: shoot, switch, reload and scope all work | **PASS** | fire=true switch=true reload=true/true scope=true |
| MOVEMENT | DESERT OUTPOST stand-up clearance check (blocked under 0.85 m ceiling, allowed after) | **PASS** | stayed prone on Z=true, on C=true, stance after ceiling removed=0 |
| BOTS | DESERT OUTPOST still exactly 3 bots after deaths/respawns (no duplicates) | **PASS** | active=3 nodes=3 bot deaths=7 |
| MENUS | Pause opens pause menu and freezes gameplay | **PASS** | paused=true menu visible=true player time advanced=false |
| MENUS | Settings from pause menu opens and closes | **PASS** | opened=true closed=true still paused=true |
| MENUS | Resume unpauses | **PASS** | paused=false |
| MENUS | ESC toggles pause | **PASS** | after 1st ESC paused=true, after 2nd ESC paused=false |
| MENUS | Restart Match reloads the map | **PASS** | new match=true kills=0 bots=3 |
| MENUS | Main Menu returns to title screen | **PASS** | match freed=true menu=res://scripts/ui/main_menu.gd paused=false |
| MATCH | Normal match length is 600 s and reads 10:00 | **PASS** | 600=10:00 0=00:00 59.4=01:00 0.3=00:01 |
| MATCH | Ranking: kills, then fewest deaths; full ties share a rank | **PASS** | A#1, B#1, C#3, D#4 |
| MATCH | Ranking: everyone tied are joint first | **PASS** | [1, 1] |
| MATCH | Bot name draw: 3 unique names, never allied_warrior (200 draws) | **PASS** | pool=30 names |
| MATCH | Countdown starts at 10:00 when gameplay begins | **PASS** | time_left=599.95 label=10:00 |
| MATCH | Player is allied_warrior; bots have 3 unique pool names | **PASS** | bots=["ONYX", "PHANTOM", "SPECTRE"] |
| MATCH | Kill feed uses allied_warrior for kills and deaths | **PASS** | allied_warrior  ✖  ONYX / PHANTOM  ✖  allied_warrior /  |
| MATCH | Bot keeps its name through death and respawn | **PASS** | alive=true name=ONYX |
| MATCH | Countdown pauses with the pause menu and resumes | **PASS** | paused at 596.28, held=true, after 1 s running 595.28 |
| MATCH | INDUSTRIAL WAREHOUSE: fresh match (scores 0, clock reset, new names) | **PASS** | time_left=3.98 names=["BISHOP", "ECHO", "SABLE"] |
| MATCH | INDUSTRIAL WAREHOUSE: timer expiry ends the match once and freezes the world | **PASS** | ended=true count=1 paused=true clock=00:00 after 238 frames |
| MATCH | INDUSTRIAL WAREHOUSE: results screen lists all 4 with rank/name/kills/deaths | **PASS** | rows=["#1 allied_warrior 1/0", "#2 ECHO 0/0", "#2 SABLE 0/0", "#4 BISHOP 0/1"] winner=WINNER:  allied_warrior |
| MATCH | INDUSTRIAL WAREHOUSE: no scoring, respawn or second end after the match ends | **PASS** | kills 1->1 end_count=1 |
| MATCH | INDUSTRIAL WAREHOUSE: Play Again restarts with fresh scores, timer and names | **PASS** | names before=["BISHOP", "ECHO", "SABLE"] after=["RAVEN", "VORTEX", "JACKAL"] |
| MATCH | URBAN WARFARE: fresh match (scores 0, clock reset, new names) | **PASS** | time_left=3.98 names=["MAVERICK", "VANDAL", "SABLE"] |
| MATCH | URBAN WARFARE: timer expiry ends the match once and freezes the world | **PASS** | ended=true count=1 paused=true clock=00:00 after 238 frames |
| MATCH | URBAN WARFARE: results screen lists all 4 with rank/name/kills/deaths | **PASS** | rows=["#1 allied_warrior 1/0", "#2 VANDAL 0/0", "#2 SABLE 0/0", "#4 MAVERICK 0/1"] winner=WINNER:  allied_warrior |
| MATCH | URBAN WARFARE: no scoring, respawn or second end after the match ends | **PASS** | kills 1->1 end_count=1 |
| MATCH | URBAN WARFARE: Play Again restarts with fresh scores, timer and names | **PASS** | names before=["MAVERICK", "VANDAL", "SABLE"] after=["HAZARD", "GHOST", "COBALT"] |
| MATCH | DESERT OUTPOST: fresh match (scores 0, clock reset, new names) | **PASS** | time_left=3.98 names=["STRYKER", "ECHO", "SPECTRE"] |
| MATCH | DESERT OUTPOST: timer expiry ends the match once and freezes the world | **PASS** | ended=true count=1 paused=true clock=00:00 after 238 frames |
| MATCH | DESERT OUTPOST: results screen lists all 4 with rank/name/kills/deaths | **PASS** | rows=["#1 allied_warrior 1/0", "#2 ECHO 0/0", "#2 SPECTRE 0/0", "#4 STRYKER 0/1"] winner=WINNER:  allied_warrior |
| MATCH | DESERT OUTPOST: no scoring, respawn or second end after the match ends | **PASS** | kills 1->1 end_count=1 |
| MATCH | Quit button is wired to quit the game | **PASS** | connections=1 (not pressed: it would end the test run) |
| MATCH | Main Menu from results returns cleanly to the title screen | **PASS** | match freed=true paused=false |
| MENUS | Temporal AA setting: Medium uses TAA, switching it off falls back to FXAA | **PASS** | taa on -> use_taa+no FXAA: true, taa off -> FXAA: true |
