# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Typing of the DOOMed** — a retro rhythm-action typing game built in Godot 4.6 (GDScript). Players fight DOOM-style enemies by typing words or playing MIDI notes. The game loads actual DOOM WAD files for sprites, sounds, and level geometry, then overlays an on-rails encounter system on top.

## Running the Project

Open in Godot 4.6+. The main scene is `main.tscn`. A DOOM WAD file (e.g., `DOOM.WAD`) must be available at runtime — the game will prompt to locate one if not found automatically.

There is no test framework, linter, or build step beyond Godot's built-in export system.

## Architecture

The codebase separates into two layers:

### Rail Framework (`rail/`)
Game-agnostic encounter/progression system. This is the reusable engine:

- **RailNetwork / RailStation / RailPath** — On-rails navigation. Stations are waypoints connected by paths. The player advances between them via `AdvanceToNextStationAction`. RailNetwork is `@tool` and auto-generates paths in the editor. At runtime it's inert — gameplay happens via Player + EncounterPoint interactions.
- **EncounterPoint** — Base class for trigger zones. Has `startActions`, `endActions`, `conditions`. RailStation extends this. Supports `one_shot` mode and configurable `disc_color` for editor visualization.
- **EncounterAction / EncounterCondition** — Resource-based behavior system. Actions can be blocking (awaited) or non-blocking. 16 action subclasses (AdvanceToNextStation, ShowDialog, ChangeWeapon, SpawnScene, SetVariable, etc.) and 2 condition subclasses.
- **Weapon / Weakness / HitPoint** — Dual-input combat. Weapons fire via keyboard (TypingGun) or MIDI (MidiGun). Enemies have weaknesses per fire type. TypingWeakness generates words scaled by difficulty; MidiWeakness uses scales/chords.
- **Enemy + StateMachine** — Enemies use a state machine (INACTIVE → IDLE → MOVING/ATTACKING → DYING → DEAD). States are child nodes of the StateMachine node.

### Game-Specific Code (`scenes/`, `enemies/`, `weapons/`, `wads/`)
DOOM-specific implementations built on the Rail framework:

- **DoomPlayer** extends Player with 8 weapon scenes and weapon cycling
- **9 enemy types** (Zombie, Imp, Cacodemon, etc.) extend Enemy with DOOM sprites/stats
- **8 weapons** (Fist through BFG) — each a scene in `weapons/doom/`
- **WAD integration** — `main.gd` orchestrates: load WAD → parse geometry → spawn player/enemies/items/decorations → load matching RailNetwork

### Level System (`levels/`)
Each WAD map (E1M1, E1M2, etc.) pairs with a `.tscn` in `levels/` by naming convention. `main.gd._loadRailNetwork(map_name)` loads `res://levels/<map_name>.tscn` automatically. Graceful fallback if no scene exists.

## Autoloads

| Singleton | Path | Purpose |
|-----------|------|---------|
| `Game` | `rail/scenes/Game/Game.tscn` | Player ref, WAD loader, state vars, sprite/sound/font fetching |
| `EventBus` | `rail/scenes/EventBus/EventBus.tscn` | Global signals (playerFireKey, enemyKilled, startEncounter, levelExitReached, etc.) |
| `Utils` | `rail/scenes/Utils/Utils.tscn` | MIDI note names, font helpers, sound playback |
| `SaveManager` | `rail/scenes/Save/SaveManager.gd` | Slot-based save/load (JSON to user://saves/) |
| `SettingsManager` | `rail/scenes/Save/SettingsManager.gd` | Persists last WAD path and settings |

## Key Patterns

- **`@tool` scripts** — RailNetwork, RailStation, RailPath, and EncounterPoint are all `@tool` for editor visualization. Guard runtime-only code with `if !Engine.is_editor_hint()`. Watch for `get_tree()` being null during scene instantiation before `add_child`.
- **WAD coordinate scaling** — The WAD addon pre-scales all coordinates by `scaleFactor (0.03125, 0.038, 0.03125)` during parsing. `main.gd._wadToWorld(pos)` offsets positions so the player spawn is at world origin.
- **Group-based lookups** — `AdvanceToNextStationAction._find_rail_path()` searches `get_tree().get_nodes_in_group("rail_paths")` globally. Safe because only one RailNetwork is loaded at a time.
- **Resource-based actions** — EncounterActions are Resources (not Nodes), configured via the inspector on each station's `startActions`/`endActions` arrays. The typed array uses `Array[EncounterAction]`.

## Key Enums (`rail/resources/Enums.gd`)

- `WEAPON_FIRE_TYPE`: MIDI, TYPING, MOUSE, NONE
- `ENEMY_STATE`: INACTIVE, IDLE, MOVING, ATTACKING, DYING, DEAD
- `ARMOR_TYPE`: GREEN, BLUE
