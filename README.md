# Subway Dash

A colorful 3D endless subway runner built in Godot 4.7. Race through a busy city, dodge barriers, overhead gates, and trains, switch between three lanes, and collect coins. Some trains can be boarded. Track sections, obstacles, and coin trails are generated as you run.

## Run

Open `project.godot` in Godot 4.7+ and press **F6** (current scene) or **F5** (project). Press **START RUN** to begin and **RUN AGAIN** after a crash.

## Controls

- **Left / Right arrows** or **A / D**: switch lanes
- **Space**, **Up**, or **W**: jump barriers
- **Down**, **S**, or **Shift**: slide under gates

Distance and collected coins are shown in the HUD. Speed gradually increases during each run.

## Project files

- `main.tscn`: game entry scene
- `scripts/runner_game.gd`: procedural 3D world, player movement, obstacles, pickups, and UI

## Sparky MCP

The Swallowtail addon exposes the running editor on loopback only using Streamable HTTP at `http://127.0.0.1:9100/mcp` (unless that port is occupied; it can auto-select 9100–9115). Keep this addon enabled while developing. It provides editor control and game inspection tools; disable it and exclude `addons/swallowtail/*` from export builds before shipping.
