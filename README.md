# Memory Digger

A casual memory game for Android, built with Godot 4.7 (GDScript).

Diamonds appear on a themed grid for a few seconds, then vanish. Dig where you remember them.

## How to play

1. **Memorize** – watch where the diamonds are before the timer bar runs out.
2. **Dig** – tap cells to dig. You have a limited number of shovels (shown under the score).
3. **Pass** – find enough diamonds to hit the level's accuracy target, then tap **Next level**.
4. **Fail** – missing the target costs one of your 3 lives; tap **Retry**. Lose all lives and it's game over.
5. **High scores** – if your score makes the top 5, enter a 5-letter name. The table shows on the start screen.

Each level adds diamonds, shortens memorize time, gives fewer spare shovels and raises the accuracy target. Themes rotate every 3 levels: grass, city, desert.

## Requirements

- macOS with [Homebrew](https://brew.sh)
- Godot 4.7
- For Android: JDK 17, Android SDK and Godot export templates

`./scripts/setup.sh` installs the toolchain once.

## Commands

| Command | What it does |
|---|---|
| `./scripts/run.sh` | Run on desktop (mouse emulates touch) |
| `./scripts/test.sh` | Headless tests; exits non-zero unless they print `OK` |
| `./scripts/android.sh` | Build the APK, install and launch on a connected phone |
| `./scripts/android.sh --build-only` | Build `build/memory-digger-debug.apk` only |

Set `GODOT=/path/to/godot` to use a specific Godot binary.

## Project layout

```
scenes/Menu.tscn          start screen: New Game, sound/music toggles, high scores
scenes/Main.tscn          game screen: board + HUD
scripts/GameManager.gd    state machine, level config, scoring, lives
scripts/GridController.gd board drawing, touch input, dig effects
scripts/Save.gd           autoload: high scores + settings (user://save.cfg)
scripts/Sound.gd          autoload: sound effects + music, synthesized in code
tests/test_level.gd       headless checks
icon/                     app icon: SVG sources + generated PNGs
```

After editing `icon/*.svg`, regenerate the PNGs with `godot --headless --path . -s icon/make_icons.gd`.

All graphics and sounds are generated in code for now; there are no asset files yet.
