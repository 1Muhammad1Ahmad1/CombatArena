# CombatArena build log

## 2026-10-27

### Environment audit
| Item | Result |
|---|---|
| OS | Windows 11 Pro 10.0.26300 |
| CPU | Intel Core i7-8850H, 6 cores / 12 threads |
| RAM | 15.8 GB |
| GPU | NVIDIA Quadro P2000 (4 GB VRAM, driver 32.0.15.8142) + Intel UHD 630 |
| Disk | C: 46.5 GB free, D: 221 GB free |
| Git / Python | present (Git for Windows, Python 3.12.0) |
| Visual Studio / Unreal / Epic Launcher | not installed |

### Engine decision
- Unreal Engine 5 was attempted first. `winget install EpicGames.EpicGamesLauncher` failed twice:
  the network resets connections to `epicgames-download1.akamaized.net` (curl error 35, also outside the sandbox).
- The user then switched the project to **Godot 4 + GDScript**. No Unreal, Epic Launcher or Visual Studio was installed;
  no installer was left running.

### Tools installed (official GitHub release assets)
| File | Location |
|---|---|
| Godot_v4.7.2-stable_win64.exe.zip (82 MB) | `C:\GameDevelopment\Tools\Godot\` |
| Godot_v4.7.2-stable_export_templates.tpz (1.28 GB download) | only `windows_release_x86_64.exe`, `windows_debug_x86_64.exe`, `version.txt` extracted to `%APPDATA%\Godot\export_templates\4.7.2.stable\` |

### Build steps
1. Project created by hand at `C:\GameDevelopment\CombatArena` (`project.godot`, one `main.tscn`, everything else built from GDScript).
2. `Godot --headless --path . --import` - OK.
3. Smoke run `--quit-after 120` - main menu loads, no script errors.
4. Test suite run 1: suite failed to parse (untyped `side`/`from` variables) - fixed, and `main.gd` now quits if the suite fails to load.
5. Test suite run 2: 63/72 pass. Navigation queries returned (0,0,0): bots were spawned before the navigation map's first sync.
   Fix: `match.gd` waits until the baked navmesh answers queries before spawning anything.
6. Test suite run 3: bots never noticed a player in front of them (they turned toward their patrol route first).
   Fix: bots perceive on their first active frame and stop to look at anything suspicious.
7. Test suite run 4: 125/126 checks pass; one Urban patrol point sat inside a building - moved.
8. Viewmodel scale reduced (0.25 -> 0.2), HUD text outlines added after reviewing rendered frames.
9. `Godot --headless --export-release "Windows Desktop" build/CombatArena.exe` - pack completes (`savepack DONE`);
   the *editor* process then exits with 0xC0000005 during shutdown. The exported exe is verified separately (see TEST_RESULTS.md).

### Commands
```
# tests (editor binary, project folder)
Godot_v4.7.2-stable_win64_console.exe --headless --path C:\GameDevelopment\CombatArena --fixed-fps 60 -- --run-tests
# export
Godot_v4.7.2-stable_win64_console.exe --headless --path C:\GameDevelopment\CombatArena --export-release "Windows Desktop" C:/GameDevelopment/CombatArena/build/CombatArena.exe
# tests inside the exported game
CombatArena.exe --headless --fixed-fps 60 -- --run-tests      (report: %APPDATA%\Godot\app_userdata\CombatArena\TEST_RESULTS_EXPORTED.md)
# performance
CombatArena.exe -- --showcase=0 --benchmark                     (appends to %APPDATA%\Godot\app_userdata\CombatArena\benchmark.txt)
```

## 2026-10-27 (later): free-for-all + graphics update

- Git checkpoint `b9ece4a` (tag `pre-ffa-graphics`) before any edits.
- Renderer inspected: Forward+ (kept). Visual features chosen for the Quadro P2000: AgX tonemap, 2 shadow splits on Low/Medium
  and 4 on High/Epic, SSAO and shadowed spot lamps only on High/Epic, `visibility_range_end` on small props,
  automatic mesh LODs from glTF import, shared materials, 128 px generated textures.
- Assets: Quaternius Toon Shooter Game Kit (CC0). The pack's Google Drive folder IDs were read in the in-app browser,
  then 37 glTF files (9.1 MB) were downloaded with `curl` from `drive.usercontent.google.com`. Details in ASSET_CREDITS.md.
- Before screenshots: `-- --photo-tour=<dir>` (tests/photo_tour.gd) from fixed viewpoints -> `screenshots/before`.
- Implemented: 3-bot free-for-all, shared combatant targeting, bot-vs-bot damage and kill credit, scoreboard, rigged animated
  bots, CC0 viewmodels, CC0 props, per-map lighting, new effects, HUD plates.
- Test-suite runs: 14 failures -> 15 -> 0. The failures came from test setup, not game logic:
  (1) frozen bots were valid FFA targets (added `bot.bench()`);
  (2) the kill-credit baseline was wrong;
  (3) the duel spot was the same spawn the player was caged at, so a bot spawned inside the cage.
  The trace showed the shooter standing on the cage roof.
- Fixed from rendered screenshots: character scale 0.62 -> 0.8 (headshots were impossible at 0.62), stand-in collision boxes
  visible under street lights and trees (now invisible blockers), and a barrier blocking the Desert spawn view.
- Benchmark found a 242 ms hitch. Combat effects are now pre-warmed during loading; hitches still occur intermittently (TEST_RESULTS.md).
- Exported `build/CombatArena.exe` (118 MB). The suite inside it reports 152 PASS / 0 FAIL / 1 NOT TESTED.

```
# matching screenshots (needs a GPU window)
Godot_v4.7.2-stable_win64_console.exe --path C:\GameDevelopment\CombatArena --resolution 1280x720 -- --photo-tour=C:/GameDevelopment/CombatArena/screenshots/after
# benchmark a preset/resolution
CombatArena.exe -- --showcase=0 --benchmark --bench-quality=2 --bench-res=1920x1080
```

## 2026-10-27 (realistic weapons round)
- Checkpoint commit `8fc50d5`. The baseline viewmodel frames were captured from that commit in a temporary worktree
  (`screenshots/v2_baseline`).
- Assets:
  - FPS arms + AK-74M (CC-BY 4.0, Cransh): downloaded with curl from the redistribution on GitHub.
  - M700 (CC0, Stein Games): itch.io free download through the in-app browser, with your approval. Scripting the itch
    download flow was refused by the safety classifier, so it was not used.
  - Poly Haven props and ambientCG textures (CC0): downloaded through their public APIs.
- Rig integration problems solved:
  - The camera initially looked backwards. The rifle bone runs stock-ward and the skeleton is Z-up. Fixed by framing
    along the scene's +Z.
  - The ADS capture was not aiming: the window lost focus and Godot released held actions. Added a `force_aim` capture hook.
  - The sniper hip offset was overwritten by the default (wrong order of metadata writes).
- Material swap: ambientCG PaintedMetal009 dropped (camo-like rust pattern).
- Build size: 344 MB -> 234 MB. Arms/AK textures capped at 2048 px; screenshots and build_logs excluded with `.gdignore`;
  unused asset folders excluded from export.
- Export failure fixed: Windows PowerShell 5.1 `Set-Content -Encoding utf8` wrote a BOM into `export_presets.cfg`
  ("Invalid export preset name"). Files are now written with UTF-8 without BOM.
- Results: 152 PASS / 0 FAIL in the editor and in the exported exe. Benchmarks are in TEST_RESULTS.md.
## 2026-10-28 (realistic bot soldiers)
- Downloaded from Mixamo in the owner's Chrome session (owner signed in and approved): characters Swat, Swat Guy,
  Gas Mask (FBX, T-pose) and clips Rifle Idle, Rifle Walk (In Place), Rifle Run (In Place), Firing Rifle, Hit Reaction,
  Death From The Front (FBX, without skin, 30 fps, no keyframe reduction). No walk-while-shooting rifle clip exists
  (the "Standing Aim Walk Forward" result is a bow clip), so it is composited in code. Originals kept in
  `assets/incoming/` (git-ignored by Godot via .gdignore); working copies in `assets/mixamo/`.
- The Gas Mask download stalled once in Chrome ("Unconfirmed ….crdownload", 97 MB); re-downloaded with the skin.
- Godot's FBX importer extracted 27 embedded textures; 21 were 4096² (Swat Guy, Gas Mask). Resized to 1024² with PIL.
- `bot.gd`: per-character AnimationLibrary built at load (hip height rescaled to each skeleton; Walk_Shoot/Run_Shoot =
  locomotion legs + Firing Rifle spine/arms with hip-rotation compensation; fire clip turned by its measured
  hand-to-hand yaw so the rifle aims forward). Rifle = AK-74M body + magazine meshes from the viewmodel pack,
  placed each frame from the right hand towards the left hand. Muzzle marker on the rifle.
- Problems found and fixed: viewmodel hid the bots in captures (tour now pauses the player); rifle aimed ~45° left in
  firing clips (bladed stance), fixed by the measured yaw correction; stale texture UIDs in the cached AK import
  (54 warnings) fixed by re-importing `assets/fps_ak74m/scene.gltf`.
- Export excludes `assets/quaternius/characters/*` (unused). Exe 234 MB -> 273 MB.
- Tests: 152 PASS / 0 FAIL / 1 NOT TESTED in editor and exe. Benchmarks in TEST_RESULTS.md.
- Capture: `Godot --path . --resolution 1280x720 -- --bot-tour=<dir>` (tests/bot_tour.gd).
- Follow-up: left-hand two-bone IK (SkeletonModifier3D `bot_hands.gd`, runs after the animation) puts the left wrist
  on the AK handguard (measured error 0.000 m); headshot line now follows the live neck bone (was a fixed 1.47 m).
  Tests 152 PASS / 0 FAIL.

## 2026-10-28 (map graphics overhaul)
- Downloads: 13 ambientCG sets through **Neat Download Manager 1.4.24** (Chrome extension; NDM has no documented CLI,
  verified by registry/exe inspection; direct `ambientcg.com/get?file=...zip` links are captured automatically, no
  dialog). ZIPs CRC-tested and size-matched to NDM's database, then moved to `assets/downloads/_zips` and extracted to
  `assets/downloads/<map>/<materials|decals>/`. 40 Poly Haven glTF models via the Poly Haven API (fetch started before
  the NDM instruction); moved to `assets/downloads/<map>/models/`. Manifest: `assets/downloads/MANIFEST.csv`.
  Tools: `C:\GameDevelopment\Tools\scripts\ph_fetch.py`, `organize_downloads.py`.
- Code: `kit.gd` (pieces out of modular kits, LOD-copy builder, material tweaks); `map_base.gd` gained the facade
  building generator, sidewalks/kerbs, decals, debris/rubble, wires, power poles, balconies, boarded windows, stacked
  sandbags, I-beams/trusses/struts, duct and pipe runs, pallets, grating, open railings, floor planes; maps rewritten
  around the same collision layout.
- Profiling (fixed camera, `--bench-spot`, `--bench-off`, `--scene-stats` added to main.gd): first Urban build ran 49 FPS
  Medium with 1.56M triangles / 1221 draws. Causes and fixes: map-wide MultiMeshes never culled (batched per building
  side + occluders: 77 FPS), screen effects ~4 ms (kept), dense scanned props (capped at 6k triangles), transparent
  double-sided glass (opaque, single-sided), far facade LOD copies from import LODs. Medium Urban ended at ~84 FPS.
  High: 34-38 -> 52-64 FPS by FSR 2 at 67 % (no MSAA), SSR moved to Epic, 2 shadow cascades, facade shadows Epic only.
- Tests: 152 PASS / 0 FAIL / 1 NOT TESTED in editor and exe (one test updated for the new High preset).
- Medium optimisation pass: added in-run A/B profiling (`--bench-ab=ssao,glow,props,...`) because separate runs
  drifted with laptop thermals. Warehouse costs found: SSAO 3.3 ms, triplanar roof/floor 1.9 ms, props 1.5 ms,
  facades 1.6 ms, glow 0.9 ms, lights 0.9 ms. Fixed: UV-mapped floor/roof planes, glow off on Medium, prop budgets by
  size, no shadows for small props, smaller fill lights, 18 m facade LOD indoors. GPU time Warehouse 12.1-12.9 -> 9.2-9.8
  ms, Urban 11.0-11.6 -> 9.6-10.1 ms. SSAO detail pass and SSAO radius tested: no measurable effect, left as is.
  CPU found throttled to 31 % clock during the session (control run of the previous exe also slowed), so FPS was not
  re-recorded. Tests 152/0/1 in editor and exe.

## 2026-10-28 (timed matches and results screen)
- Added a 600 s match clock (pausable; drives `end_match()` once), player name `allied_warrior`, random unique bot
  call-signs per match, frozen ranked results with shared ranks, results screen (Play Again / Main Menu / Quit).
- Tests: 25 new MATCH checks (format, ranking and ties, name draws, 10:00 start, names in scoreboard and kill feed,
  name kept through respawn, pause holds the clock, expiry/freeze/results/no-late-scoring/Play Again on all three
  maps with a 4 s test duration, Main Menu from results, Quit wired). Editor and exe: 177 PASS, 0 FAIL, 1 NOT TESTED.
- Windowed smoke test of the exported exe: `--results-tour` captured HUD clock and results (`screenshots/v8_match_exe`).

## 2026-10-28 (distant rendering quality)
- Baseline: Medium 1280x720 native, FXAA, VSync on (60 Hz cap). Route benchmark added (`--bench-path`: avg, 1 % low,
  p99, GPU ms, VRAM). First baseline runs were taken while the CPU was throttled to 31 % clock (Medium avg 75.5 / 60.2 /
  86.4); the before/after used in TEST_RESULTS.md was re-run later at full clock with only the fog/AA files reverted.
- Probe (`tests/quality_probe.gd`, `tools/quality_metrics.py`) isolated fog as the washed-out cause and aliasing as the
  grain/jaggies cause; TAA cost measured in-run (1.6-2.3 ms A/B), SMAA 0.2 ms but worse than FXAA on the metrics.
- Changes: fog (warehouse off, urban/desert lower, aerial perspective lower), TAA on Medium/Epic + settings toggle,
  1 new test. Tests 178/0/1 in editor and exe; windowed exe smoke test passed.
