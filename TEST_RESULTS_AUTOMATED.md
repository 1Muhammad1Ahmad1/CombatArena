# CombatArena automated test run

Generated: 2026-10-28T19:49:26  |  Godot 4.7.2-stable (official)  |  headless, fixed 60 fps

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
| WEAPONS | INDUSTRIAL WAREHOUSE assault rifle fires and damages bot | **PASS** | bot HP 76 -> 55, AR ammo 30 -> 29 |
| COMBAT | INDUSTRIAL WAREHOUSE bot health reaches 0 and bot dies | **PASS** | alive=false after 4 more shots, death events +1, kills +1 |
| COMBAT | INDUSTRIAL WAREHOUSE no repeated bot death events | **PASS** | death events +1 after extra damage on corpse |
| HUD | INDUSTRIAL WAREHOUSE kill counter updates | **PASS** | label: 'KILLS  1      DEATHS  0' |
| BOTS | INDUSTRIAL WAREHOUSE bot respawns after 3 seconds | **PASS** | alive at ~2.9 s: false, alive at ~3.3 s: true, active=3 |
| WEAPONS | INDUSTRIAL WAREHOUSE Q switches to sniper and back | **PASS** | after 1st Q cur=true, after 2nd Q cur=0 |
| WEAPONS | INDUSTRIAL WAREHOUSE ammo persists across switches | **PASS** | AR ammo 26 -> 26 |
| WEAPONS | INDUSTRIAL WAREHOUSE switching cannot bypass fire rate | **PASS** | shot1=true, shot ~1.1 s later blocked=true, shot after 1.3 s fired=true |
| WEAPONS | INDUSTRIAL WAREHOUSE sniper scope works | **PASS** | scoped=true fov=14.0 overlay=true |
| WEAPONS | INDUSTRIAL WAREHOUSE sniper fires and headshot kills | **PASS** | bot HP 60 -> 0 (95 dmg x2.5 head) |
| WEAPONS | INDUSTRIAL WAREHOUSE reload refills magazine from reserve | **PASS** | started=true ammo=30 reserve 180 -> 153 |
| HUD | INDUSTRIAL WAREHOUSE HUD shows real health and ammo | **PASS** | hp label '100' (hp 100), ammo label '30' (ammo 30) |
| BOTS | INDUSTRIAL WAREHOUSE bot detects player | **PASS** | bot state=COMBAT awareness=1.00 |
| BOTS | INDUSTRIAL WAREHOUSE bot aims and fires | **PASS** | 16 shots fired |
| COMBAT | INDUSTRIAL WAREHOUSE bot bullets reduce player health | **PASS** | player HP 100 -> 84, 2 hits / 16 shots |
| HUD | INDUSTRIAL WAREHOUSE damage indicator shown | **PASS** | 2 active indicators |
| COMBAT | INDUSTRIAL WAREHOUSE player death counted exactly once | **PASS** | deaths 0 -> 1, alive=false |
| HUD | INDUSTRIAL WAREHOUSE death counter updates | **PASS** | label: 'KILLS  2      DEATHS  1' |
| COMBAT | INDUSTRIAL WAREHOUSE player respawns with 100 HP | **PASS** | alive=true hp=100 |
| FFA | INDUSTRIAL WAREHOUSE bots cannot damage themselves | **PASS** | self hit result=false hp 100 -> 100 |
| FFA | INDUSTRIAL WAREHOUSE bots acquire each other as targets | **PASS** | first acquisition after 0.48 s (A target=KESTREL, B target=none) |
| FFA | INDUSTRIAL WAREHOUSE bots fire at and damage each other | **PASS** | shots A=22 B=20, bot-on-bot damage events=24 |
| FFA | INDUSTRIAL WAREHOUSE bot-vs-bot kill credited to the real attacker | **PASS** | after 4.0 s: HUNTER killed KESTREL (killer kills 0 -> 1, victim deaths +1, player kills unchanged 2) |
| FFA | INDUSTRIAL WAREHOUSE killer drops the dead target | **PASS** | killer target now: none |
| FFA | INDUSTRIAL WAREHOUSE bot killed by a bot respawns after 3 s, still 3 slots | **PASS** | victim alive=true active=2 nodes=3 |
| FFA | INDUSTRIAL WAREHOUSE observed match: bots fight each other with the player hidden | **PASS** | 60 s: 6 bot-vs-bot kills, 6 bot deaths, player hit 0 times [], scoreboard KESTREL 5/3, GRIZZLY 3/3, allied_warrior 2/1, HUNTER 1/4 |
| FFA | INDUSTRIAL WAREHOUSE no self-targeting and no lingering dead targets | **PASS** | self-target frames=0, frames aiming at a corpse >0.2 s=0 |
| FFA | INDUSTRIAL WAREHOUSE target selection is stable | **PASS** | 14 live-to-live target switches across 3 bots in 60 s |
| MOVEMENT | INDUSTRIAL WAREHOUSE WASD movement | **PASS** | W 3.35 m, S -2.21 m, D 2.23 m, A -2.21 m (along facing axes) |
| MOVEMENT | INDUSTRIAL WAREHOUSE sprint is faster than walking | **PASS** | walk 5.59 m/s, sprint 8.59 m/s |
| MOVEMENT | INDUSTRIAL WAREHOUSE jump | **PASS** | peak height 1.51 m |
| MOVEMENT | INDUSTRIAL WAREHOUSE C crouches (1.2 m capsule, lowered camera) | **PASS** | stance=1 shape=CapsuleShape3D height=1.20 eye=1.08 |
| MOVEMENT | INDUSTRIAL WAREHOUSE crouched: slower movement and shooting works | **PASS** | crouch speed 2.99 m/s, shot fired=true |
| MOVEMENT | INDUSTRIAL WAREHOUSE C again stands up | **PASS** | stance=0 |
| MOVEMENT | INDUSTRIAL WAREHOUSE double-tap C slides (faster than a run, ends crouched) | **PASS** | run 8.60 m/s, slide peak 10.29 m/s, started=true, stance after=1 |
| MOVEMENT | INDUSTRIAL WAREHOUSE double-tap C standing still just toggles crouch (no slide) | **PASS** | stance=0 slide_t=0.00 speed=0.00 |
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
| BOTS | URBAN WARFARE bot aims and fires | **PASS** | 2 shots fired |
| COMBAT | URBAN WARFARE bot bullets reduce player health | **PASS** | player HP 100 -> 84, 2 hits / 2 shots |
| HUD | URBAN WARFARE damage indicator shown | **PASS** | 2 active indicators |
| COMBAT | URBAN WARFARE player death counted exactly once | **PASS** | deaths 0 -> 1, alive=false |
| HUD | URBAN WARFARE death counter updates | **PASS** | label: 'KILLS  2      DEATHS  1' |
| COMBAT | URBAN WARFARE player respawns with 100 HP | **PASS** | alive=true hp=100 |
| FFA | URBAN WARFARE bots cannot damage themselves | **PASS** | self hit result=false hp 100 -> 100 |
| FFA | URBAN WARFARE bots acquire each other as targets | **PASS** | first acquisition after 0.48 s (A target=none, B target=MAVERICK) |
| FFA | URBAN WARFARE bots fire at and damage each other | **PASS** | shots A=16 B=19, bot-on-bot damage events=21 |
| FFA | URBAN WARFARE bot-vs-bot kill credited to the real attacker | **PASS** | after 6.8 s: REAPER killed MAVERICK (killer kills 0 -> 1, victim deaths +1, player kills unchanged 2) |
| FFA | URBAN WARFARE killer drops the dead target | **PASS** | killer target now: none |
| FFA | URBAN WARFARE bot killed by a bot respawns after 3 s, still 3 slots | **PASS** | victim alive=true active=2 nodes=3 |
| FFA | URBAN WARFARE observed match: bots fight each other with the player hidden | **PASS** | 60 s: 7 bot-vs-bot kills, 7 bot deaths, player hit 0 times [], scoreboard HAZARD 4/2, REAPER 3/4, allied_warrior 2/1, MAVERICK 2/4 |
| FFA | URBAN WARFARE no self-targeting and no lingering dead targets | **PASS** | self-target frames=0, frames aiming at a corpse >0.2 s=0 |
| FFA | URBAN WARFARE target selection is stable | **PASS** | 9 live-to-live target switches across 3 bots in 60 s |
| MOVEMENT | URBAN WARFARE WASD movement | **PASS** | W 3.35 m, S -2.21 m, D 2.23 m, A -2.21 m (along facing axes) |
| MOVEMENT | URBAN WARFARE sprint is faster than walking | **PASS** | walk 5.59 m/s, sprint 8.59 m/s |
| MOVEMENT | URBAN WARFARE jump | **PASS** | peak height 1.51 m |
| MOVEMENT | URBAN WARFARE C crouches (1.2 m capsule, lowered camera) | **PASS** | stance=1 shape=CapsuleShape3D height=1.20 eye=1.08 |
| MOVEMENT | URBAN WARFARE crouched: slower movement and shooting works | **PASS** | crouch speed 2.99 m/s, shot fired=true |
| MOVEMENT | URBAN WARFARE C again stands up | **PASS** | stance=0 |
| MOVEMENT | URBAN WARFARE double-tap C slides (faster than a run, ends crouched) | **PASS** | run 8.60 m/s, slide peak 10.29 m/s, started=true, stance after=1 |
| MOVEMENT | URBAN WARFARE double-tap C standing still just toggles crouch (no slide) | **PASS** | stance=0 slide_t=0.00 speed=0.00 |
| MOVEMENT | URBAN WARFARE Z goes prone (box collision, camera near floor) | **PASS** | stance=2 shape=BoxShape3D eye=0.36 |
| MOVEMENT | URBAN WARFARE prone crawling works (slow) | **PASS** | crawled 1.10 m in 1 s |
| MOVEMENT | URBAN WARFARE cannot sprint or jump while prone | **PASS** | speed with sprint held 1.10 m/s, height change 0.00 |
| MOVEMENT | URBAN WARFARE prone: shoot, switch, reload and scope all work | **PASS** | fire=true switch=true reload=true/true scope=true |
| MOVEMENT | URBAN WARFARE stand-up clearance check (blocked under 0.85 m ceiling, allowed after) | **PASS** | stayed prone on Z=true, on C=true, stance after ceiling removed=0 |
| BOTS | URBAN WARFARE still exactly 3 bots after deaths/respawns (no duplicates) | **PASS** | active=3 nodes=3 bot deaths=10 |
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
| BOTS | DESERT OUTPOST bot aims and fires | **PASS** | 20 shots fired |
| COMBAT | DESERT OUTPOST bot bullets reduce player health | **PASS** | player HP 100 -> 84, 5 hits / 20 shots |
| HUD | DESERT OUTPOST damage indicator shown | **PASS** | 2 active indicators |
| COMBAT | DESERT OUTPOST player death counted exactly once | **PASS** | deaths 0 -> 1, alive=false |
| HUD | DESERT OUTPOST death counter updates | **PASS** | label: 'KILLS  2      DEATHS  1' |
| COMBAT | DESERT OUTPOST player respawns with 100 HP | **PASS** | alive=true hp=100 |
| FFA | DESERT OUTPOST bots cannot damage themselves | **PASS** | self hit result=false hp 100 -> 100 |
| FFA | DESERT OUTPOST bots acquire each other as targets | **PASS** | first acquisition after 0.48 s (A target=none, B target=GRIZZLY) |
| FFA | DESERT OUTPOST bots fire at and damage each other | **PASS** | shots A=35 B=38, bot-on-bot damage events=23 |
| FFA | DESERT OUTPOST bot-vs-bot kill credited to the real attacker | **PASS** | after 12.3 s: PHANTOM killed GRIZZLY (killer kills 0 -> 1, victim deaths +1, player kills unchanged 2) |
| FFA | DESERT OUTPOST killer drops the dead target | **PASS** | killer target now: none |
| FFA | DESERT OUTPOST bot killed by a bot respawns after 3 s, still 3 slots | **PASS** | victim alive=true active=2 nodes=3 |
| FFA | DESERT OUTPOST observed match: bots fight each other with the player hidden | **PASS** | 60 s: 5 bot-vs-bot kills, 5 bot deaths, player hit 0 times [], scoreboard PHANTOM 3/2, NOMAD 3/2, allied_warrior 2/1, GRIZZLY 1/4 |
| FFA | DESERT OUTPOST no self-targeting and no lingering dead targets | **PASS** | self-target frames=0, frames aiming at a corpse >0.2 s=0 |
| FFA | DESERT OUTPOST target selection is stable | **PASS** | 4 live-to-live target switches across 3 bots in 60 s |
| MOVEMENT | DESERT OUTPOST WASD movement | **PASS** | W 3.35 m, S -2.21 m, D 2.23 m, A -2.21 m (along facing axes) |
| MOVEMENT | DESERT OUTPOST sprint is faster than walking | **PASS** | walk 5.59 m/s, sprint 8.59 m/s |
| MOVEMENT | DESERT OUTPOST jump | **PASS** | peak height 1.51 m |
| MOVEMENT | DESERT OUTPOST C crouches (1.2 m capsule, lowered camera) | **PASS** | stance=1 shape=CapsuleShape3D height=1.20 eye=1.08 |
| MOVEMENT | DESERT OUTPOST crouched: slower movement and shooting works | **PASS** | crouch speed 2.99 m/s, shot fired=true |
| MOVEMENT | DESERT OUTPOST C again stands up | **PASS** | stance=0 |
| MOVEMENT | DESERT OUTPOST double-tap C slides (faster than a run, ends crouched) | **PASS** | run 8.60 m/s, slide peak 10.29 m/s, started=true, stance after=1 |
| MOVEMENT | DESERT OUTPOST double-tap C standing still just toggles crouch (no slide) | **PASS** | stance=0 slide_t=0.00 speed=0.00 |
| MOVEMENT | DESERT OUTPOST Z goes prone (box collision, camera near floor) | **PASS** | stance=2 shape=BoxShape3D eye=0.36 |
| MOVEMENT | DESERT OUTPOST prone crawling works (slow) | **PASS** | crawled 1.10 m in 1 s |
| MOVEMENT | DESERT OUTPOST cannot sprint or jump while prone | **PASS** | speed with sprint held 1.10 m/s, height change 0.00 |
| MOVEMENT | DESERT OUTPOST prone: shoot, switch, reload and scope all work | **PASS** | fire=true switch=true reload=true/true scope=true |
| MOVEMENT | DESERT OUTPOST stand-up clearance check (blocked under 0.85 m ceiling, allowed after) | **PASS** | stayed prone on Z=true, on C=true, stance after ceiling removed=0 |
| BOTS | DESERT OUTPOST still exactly 3 bots after deaths/respawns (no duplicates) | **PASS** | active=3 nodes=3 bot deaths=8 |
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
| MATCH | Player is allied_warrior; bots have 3 unique pool names | **PASS** | bots=["GRIZZLY", "STRYKER", "HUNTER"] |
| MATCH | Kill feed uses allied_warrior for kills and deaths | **PASS** | allied_warrior  ✖  GRIZZLY / STRYKER  ✖  allied_warrior /  |
| MATCH | Bot keeps its name through death and respawn | **PASS** | alive=true name=GRIZZLY |
| MATCH | Countdown pauses with the pause menu and resumes | **PASS** | paused at 596.28, held=true, after 1 s running 595.28 |
| MATCH | INDUSTRIAL WAREHOUSE: fresh match (scores 0, clock reset, new names) | **PASS** | time_left=3.98 names=["WARDEN", "STRYKER", "VORTEX"] |
| MATCH | INDUSTRIAL WAREHOUSE: timer expiry ends the match once and freezes the world | **PASS** | ended=true count=1 paused=true clock=00:00 after 238 frames |
| MATCH | INDUSTRIAL WAREHOUSE: results screen lists all 4 with rank/name/kills/deaths | **PASS** | rows=["#1 allied_warrior 1/0", "#2 STRYKER 0/0", "#2 VORTEX 0/0", "#4 WARDEN 0/1"] winner=WINNER:  allied_warrior |
| MATCH | INDUSTRIAL WAREHOUSE: no scoring, respawn or second end after the match ends | **PASS** | kills 1->1 end_count=1 |
| MATCH | INDUSTRIAL WAREHOUSE: Play Again restarts with fresh scores, timer and names | **PASS** | names before=["WARDEN", "STRYKER", "VORTEX"] after=["MAVERICK", "BLAZE", "VANDAL"] |
| MATCH | URBAN WARFARE: fresh match (scores 0, clock reset, new names) | **PASS** | time_left=3.98 names=["SABLE", "PHANTOM", "RAPTOR"] |
| MATCH | URBAN WARFARE: timer expiry ends the match once and freezes the world | **PASS** | ended=true count=1 paused=true clock=00:00 after 238 frames |
| MATCH | URBAN WARFARE: results screen lists all 4 with rank/name/kills/deaths | **PASS** | rows=["#1 allied_warrior 1/0", "#2 PHANTOM 0/0", "#2 RAPTOR 0/0", "#4 SABLE 0/1"] winner=WINNER:  allied_warrior |
| MATCH | URBAN WARFARE: no scoring, respawn or second end after the match ends | **PASS** | kills 1->1 end_count=1 |
| MATCH | URBAN WARFARE: Play Again restarts with fresh scores, timer and names | **PASS** | names before=["SABLE", "PHANTOM", "RAPTOR"] after=["ONYX", "STRYKER", "NOMAD"] |
| MATCH | DESERT OUTPOST: fresh match (scores 0, clock reset, new names) | **PASS** | time_left=3.98 names=["ONYX", "HUNTER", "STRYKER"] |
| MATCH | DESERT OUTPOST: timer expiry ends the match once and freezes the world | **PASS** | ended=true count=1 paused=true clock=00:00 after 238 frames |
| MATCH | DESERT OUTPOST: results screen lists all 4 with rank/name/kills/deaths | **PASS** | rows=["#1 allied_warrior 1/0", "#2 HUNTER 0/0", "#2 STRYKER 0/0", "#4 ONYX 0/1"] winner=WINNER:  allied_warrior |
| MATCH | DESERT OUTPOST: no scoring, respawn or second end after the match ends | **PASS** | kills 1->1 end_count=1 |
| MATCH | Quit button is wired to quit the game | **PASS** | connections=1 (not pressed: it would end the test run) |
| MATCH | Main Menu from results returns cleanly to the title screen | **PASS** | match freed=true paused=false |
| MENUS | Temporal AA setting: Medium uses TAA, switching it off falls back to FXAA | **PASS** | taa on -> use_taa+no FXAA: true, taa off -> FXAA: true |

Totals: 184 PASS, 0 FAIL, 1 NOT TESTED
