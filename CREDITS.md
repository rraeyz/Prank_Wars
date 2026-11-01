# Credits & Licenses

| What | Source | License | Notes |
| --- | --- | --- | --- |
| Game engine | [Godot Engine 4.4.1](https://godotengine.org) | MIT | Godot license text must ship with the game (see `docs/GODOT_LICENSE.txt`, also shown in-game credits later). |
| Renderer | Forward+ with automatic OpenGL fallback | — | |
| 3D models | Made in code from primitive shapes (`scripts/house.gd`, `avatar.gd`, `prank.gd`) | Own work | No external model files. |
| Sound effects (most) | Synthesized in code (`scripts/sfx.gd`) | Own work | |
| Sound effects `audio/splash_*`, `splat_*` | [40 CC0 water / splash / slime SFX](https://opengameart.org/content/40-cc0-water-splash-slime-sfx) by rubberduck | CC0 | trimmed, mono |
| `audio/spring_*`, `pop_*`, `punch_1`, `door_open`, `bell_*`, `cannon_1` | [100 CC0 SFX](https://opengameart.org/content/100-cc0-sfx) by rubberduck | CC0 | |
| `audio/thud_*` | [75 CC0 breaking / falling / hit sfx](https://opengameart.org/content/75-cc0-breaking-falling-hit-sfx) by rubberduck | CC0 | |
| `audio/fart_*` | [Gastric Distress](https://opengameart.org/content/gastric-distress) by LFA | CC0 | cut into 4 clips |
| `audio/boing_1` | [BOING!](https://opengameart.org/content/boing) by Aeva | CC0 | trimmed |
| `audio/grunt_*` | [Little Grunts](https://opengameart.org/content/little-grunts) by crueltyinc | CC0 | cut into 3 clips |
| Music | Generated in code (`scripts/sfx.gd`, `build_music`) | Own work | |
| Font | Godot default font (Open Sans subset bundled with the engine) | Apache 2.0 / OFL (bundled with Godot) | |
| Steam integration (Windows build only) | [GodotSteam GDExtension 4.23.2](https://codeberg.org/godotsteam/godotsteam) | MIT | Added by CI at build time. |
| Steamworks SDK runtime (`steam_api64.dll`) | Valve | Steamworks SDK Access Agreement | Redistributable with Steam games. |

Rule: only assets whose license clearly allows commercial use (CC0 preferred). Add every new asset to this table before using it.
