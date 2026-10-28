# COMBATARENA

Single-player, offline, first-person arena shooter made with Godot 4.7.2 (GDScript).
No internet, account or server is needed.

## Play
Download **`CombatArena.exe`** from the [Releases](../../releases) page (Windows, about 500 MB) and double-click it.
It is a single self-contained file (the game data is embedded), so you can copy it anywhere, including a USB stick.
If you build it yourself, it is written to `build\CombatArena.exe`.

Main menu -> **START GAME** -> pick one of the three maps.

| Key | Action |
|---|---|
| W A S D | Move |
| Mouse | Look |
| Left mouse | Fire |
| Right mouse | Aim down sights / sniper scope |
| Q | Switch assault rifle <-> sniper rifle |
| R | Reload |
| Left Shift | Sprint |
| Space | Jump (stands up from crouch) |
| C | Crouch / stand |
| C C (double-tap while moving) | Slide |
| Z | Prone / stand |
| Esc | Pause menu (Resume, Restart Match, Settings, Main Menu) |

Settings (graphics preset, resolution, fullscreen, VSync, mouse sensitivity, master/music/SFX volume, bot difficulty)
are saved to `%APPDATA%\Godot\app_userdata\CombatArena\settings.cfg`.

## Maps
1. **Industrial Warehouse** - indoor containers, catwalk, mezzanine, office corridors (close/medium range)
2. **Urban Warfare** - streets, alleys, barricades, rooftop (medium range)
3. **Desert Outpost** - fortified compound, four climbable watchtowers, open desert (long range)

Free-for-all: you (`allied_warrior`) against three bots with random names who also fight each other. Each respawns
3 seconds after being killed. The scoreboard (top-left) shows everyone's kills and deaths. Matches last 10 minutes;
at 00:00 a results screen ranks everyone by kills, then fewest deaths.

## Weapons
- **VX-4 assault rifle**: full auto, 30 rounds, 21 damage (x2 to the head), iron sights
- **HX-50 sniper rifle**: bolt action, 5 rounds, 95 damage (x2.5 to the head), 14 degree FOV scope

## Develop
- Editor: `C:\GameDevelopment\Tools\Godot\Godot_v4.7.2-stable_win64.exe`, then open this folder.
- Maps, materials, sounds and UI are generated from the scripts in `scripts/`. Guns, props and textures are
  CC0 / CC-BY assets listed in ASSET_CREDITS.md.
- **Bot characters (Mixamo) are not in this repository.** Adobe's terms don't allow redistributing the raw files.
  To run from source, sign in at https://www.mixamo.com and download these into `assets/mixamo/`
  (FBX Binary, 30 fps; characters "With Skin", animations "Without Skin" and "In Place" where offered):

  | File | Mixamo name |
  |---|---|
  | `swat.fbx` | Swat (character) |
  | `gas_mask.fbx` | Gas Mask (character) |
  | `swat_guy.fbx` | Swat Guy (character) |
  | `idle.fbx` | Rifle Idle |
  | `walk.fbx` | Rifle Walk |
  | `run.fbx` | Rifle Run |
  | `fire.fbx` | Firing Rifle |
  | `hit.fbx` | Hit Reaction |
  | `death.fbx` | Death From The Front |

  The game won't load bots without these files. The exe on the Releases page already contains them.
- Tests, export and benchmark commands are in `BUILD_LOG.md`.

