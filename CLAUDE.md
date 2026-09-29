# CLAUDE.md - Memory Digger (Godot Android Game)

## 1. Project Overview

* **Project Name:** Memory Digger (Working Title)
* **Target Platform:** Android (portrait, 720x1280 base, `canvas_items` stretch)
* **Game Engine:** Godot 4.7 (GDScript)
* **Genre:** Memory / Puzzle / Casual Mobile Game

## 2. Core Game Loop & Rules

1. **Observation Phase:** themed grid loads, `N` diamonds spawn on random non-overlapping cells, visible for `X` seconds (timer bar).
2. **Hidden Phase:** diamonds disappear.
3. **Digging Phase:** player taps cells to place diggers. `Max Diggers = ceil(N * digger_factor)`.
4. **Scoring & Progression:** each hit grants points. Pass if `hits / N >= pass_accuracy_percentage`.
   Difficulty scales per level: more diamonds, less memorize time, fewer spare diggers, higher accuracy threshold.

## 3. Level Config

`GameManager.level_config(n)` returns a dictionary (generated from the level number, no fixed table):

* `level_number`: int
* `map_theme`: String ("grass", "city", "desert")
* `diamond_count`: int (`N`)
* `memorize_time`: float (`X` seconds)
* `digger_factor`: float (e.g. 1.25)
* `pass_accuracy_percentage`: float (0.70 = 70%)

## 4. Project Layout

* `project.godot` — portrait, `canvas_items` stretch, mobile renderer, mouse→touch emulation for desktop testing.
* `scenes/Menu.tscn` + `scripts/Menu.gd` — start screen (main scene): New Game, Sound/Music ON/OFF, best score. Android back = quit.
* `scenes/Main.tscn` — root (GameManager), `Board`, HUD (`Info` label, `TimerBar`, `ActionButton`, `MenuButton`). Android back = menu.
* `scripts/GameManager.gd` — state machine (`STATE_OBSERVE`, `STATE_DIGGING`, `STATE_EVALUATING`), level config, scoring, HUD.
* `scripts/GridController.gd` — grid drawing, spawning, touch→cell mapping, dig results. Draws placeholders with `_draw()`.
* `scripts/Save.gd` (autoload `Save`) — best score + sound/music flags in `user://save.cfg` via ConfigFile.
* `scripts/Sound.gd` (autoload `Sound`) — SFX (`hit`, `miss`, `new_level`, `level_up`, `game_over`, `click`) + looping music, all synthesized in code (same approach as `../booms`). `Sound.play(name)`, `Sound.update_music()`.
* `tests/test_level.gd` — headless checks. Must `load()` game scripts at runtime, not `preload()`: autoload names don't exist yet when the test compiles.

Diamond/Digger are drawn by `GridController._draw()` for now; split into own scenes (`Diamond.tscn`, `Digger.tscn`) when real sprites/animations arrive.

## 5. Commands

* Setup (one-time toolchain): `./scripts/setup.sh`
* Run (desktop): `./scripts/run.sh`
* Tests: `./scripts/test.sh` (exits non-zero unless `tests/test_level.gd` prints `OK`)
* Phone: `./scripts/android.sh` (build + install + launch `com.ran1979.memorydigger`), `--build-only` for just the APK in `build/`
* Scripts mirror `../booms/scripts`. Android: JDK 17, SDK `/opt/homebrew/share/android-commandlinetools`, preset in `export_presets.cfg`.

## 6. Assets Checklist (placeholders drawn in code until replaced)

* [ ] Backgrounds: grass, city road, desert
* [ ] Diamond sprite/animation
* [ ] Digger / shovel sprite with dig animation
* [ ] Hole / dug tile
* [ ] Success effect (sparkles) / miss effect (dust, red X)
* [ ] UI: timer bar, diggers counter, score
* [ ] SFX: gem spawn, dig, diamond found, level win/fail

## 7. Development Instructions

* Clean, idiomatic GDScript for Godot 4, typed where it helps.
* Touch input via `InputEventScreenTouch`; highlight cell on press, dig on release in the same cell.
* Keep HUD readable on small screens.
