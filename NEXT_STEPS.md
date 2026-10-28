# Next steps

1. **Bot polish.** Mixamo also has rifle reload, crouch and strafe clips (same login); adding them would give bots a
   visible reload and side-stepping legs.
2. **A real scope model.** Install portable Blender (~350 MB) to convert the CC0 OpenGameArt "rifle scope" (.blend), or
   provide a glTF scope you like.
3. **Sniper-specific reload** (top-loading rounds) would need a bolt-action FPS animation pack. None free was found without a login.
4. **Re-measure FPS when the CPU is at full clock.** This session the i7-8850H was stuck at 31 % clock (power limit;
   check the charger is the original 130 W+ Dell adapter and the laptop is cool). Then run, from `build\`:
   `CombatArena.exe -- --showcase=0 --benchmark --bench-quality=1 --bench-res=1280x720` (showcase 0/1/2 = maps),
   results appended to `%APPDATA%\Godotpp_userdata\CombatArenaenchmark.txt`.
5. **Performance (older note).** Medium is 78–84 FPS on Warehouse/Urban (target 90): candidates are SSAO quality, fewer facade
   modules on alley sides, and baked lightmaps for the warehouse. High is 52–64 FPS. Options: lower SSAO quality on High, fewer shadowed
   spot lamps, or LODs on the Poly Haven props. Medium is comfortably above 100 FPS.
5. **Building detail.** Modular CC0 facades (window frames, doors, ledges) instead of textured boxes.
6. **Hands-on playtest** with mouse and sound, and press EXIT GAME once (the only check not automated).
7. **Map detail still missing:** realistic military vehicles (Sketchfab CC-BY models need your login), enterable
   building interiors, real container and dumpster models, tents and camouflage nets for the desert base.
8. **Distant rendering, remaining:** TAA softens the image slightly; a sharpening pass could be tested against the
   shimmer metric. Thin overhead cables still shimmer a little at long range on FXAA. Baked lighting was not used
   (maps are generated at load time, so LightmapGI cannot be baked in advance).
