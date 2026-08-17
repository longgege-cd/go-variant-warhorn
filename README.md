# War Horn · Borderline

> A Go-inspired two-player turn-based strategy game. On a 19×19 board divided by the "Borderline", players battle through dynamic scoring mechanics such as territory, siege, and annihilation.

- Engine: Godot 4.7
- Genre: Two-player turn-based strategy
- Duration: 30–60 minutes per game
- Platform: Windows (cross-platform buildable)

## Gameplay

### Match Flow: Deployment Phase → Formal Opening

Each match has two phases:

1. **Deployment Phase**: Both sides take turns placing 2 stones each (4 total) in **their own territory**. Each side has an **independent 2-minute countdown** (displayed on each score panel; a golden breathing light shows whose turn it is to deploy, and the bar turns red and breathes when under 30 seconds remain). Thinking time is paused during deployment.
2. **Formal Opening**: Begins automatically when deployment completes or the countdown runs out. A **circular expanding wave** animation (1.4 s) plays at the board center with an opening horn sound, then the thinking clock starts and players may move anywhere.

### Board & Forces

- 19×19 board; **row 10 is the Borderline** and belongs to neither side
- Rows 1–9 are Black's territory; rows 11–19 are White's territory
- Each side has **112 stones** (default; adjustable to 90 / 112 / 134 / 152 in the start menu), non-renewable

### Scoring Overview

```
Total = Occupation + Defense - Casualties
```

All scores are **computed live during play** — no endgame counting needed.

| Score Type | Components | Description |
|---|---|---|
| Occupation | Live stones + Territory | Control in the opponent's territory |
| Defense | Annihilation + Siege | Defensive results in your own territory |
| Casualties | — | Cost of being captured |

### The Four Scoring Mechanics

1. **Live stones**: A stone with liberties in the opponent's territory or on the Borderline → +1/stone
2. **Territory**: Forming an enclosure in the opponent's territory or on the Borderline → +2 per enclosed point
3. **Annihilation**: Capturing opponent stones in your own territory or on the Borderline → +2/stone
4. **Siege**: Surrounding opponent stones that lack two eyes and sufficient space → +1/stone (live dynamic)

### Siege Rules

A stone group is considered **sieged** when all three conditions hold:
1. Surrounded by the opponent (purely geometric)
2. Has not formed two independent true eyes
3. Legal empty points inside the enclosure < 4

**Not sieged means alive** — there is no "dead stones" or "seki" concept.

### Pass & Endgame

- **Pass count**: each side is limited to **2 passes** per game (not allowed during deployment)
- **Pass cooldown**: after a side passes, it must complete 2 of its own turns (move/deploy/bounce) before it may pass again; a side that has never passed may pass anytime
- **Automatic endgame**: both sides pass consecutively → game ends, and the final score is settled (including ko resolution and final life-death judgment)
- **Forced endgame**: a side runs out of forces and both sides pass consecutively, or neither side can move → immediate end

## Special Systems

### Special Forces (optional rule)

Secretly deployed special stones, 2 uses per game:
- **Stealth**: invisible to the opponent; revealed when their timer expires or an adjacent enemy stone appears
- **Three endgame bonuses** (best one applies): territory involvement doubles / survival +3 / borderline contribution +50%
- **Bounce**: when the opponent collides with a hidden stone, it is randomly bounced to one of the 8 surrounding cells

### Komi System

- Default komi: **0.5 points**
- Adjustable in the start menu with `[−]` / `[+]` buttons in 0.5-point steps (0.0–20.5)

### Replay

Built-in classic game library, supports:
- Three categories: Classic / Master / Modern games
- SGF file import
- Step forward / backward / auto-play (0.5x–4x speed)
- Jump to any move

### AI Opponent

Five AI difficulties:
- Easy: heuristic AI
- Normal: shallow search AI
- Hard: standard search AI
- Expert: search + MCTS on key positions
- Master: deeper search + more simulations

### Online Battle

LAN multiplayer based on Godot's ENet, with host/client modes. The host sets thinking time / forces / komi and starts a room; the client discovers rooms via UDP broadcast and joins.

### Language Support

Chinese and English are both supported. Click the language button on the main menu to switch; your preference is saved automatically.

## Game Modes

| Mode | Description |
|---|---|
| Local 2-Player | Play on the same screen |
| vs AI | Five AI difficulties |
| Online Battle | Host or join |
| Replay | Study classic games |

## Starting a Game

1. On the main menu choose a mode (Local 2-Player / vs AI / Online / Replay / Tutorial).
2. Set match options:
   - **Thinking time**: Amateur (Unlimited / Blitz 5m / Rapid 15m+30s×3 / Standard 30m+30s×3 / Amateur 60m+30s×5) and Professional (Pro Rapid 1h+30s×5 / Pro Normal 3h+60s×5 / Pro Grand 5h+60s×5 / Title Match 8h+60s×10); default is Unlimited
   - **Komi**: default 0.5, `[−]` / `[+]` steps of 0.5 (0.0–20.5)
   - **Forces**: 90 / 112 / 134 / 152, default 112
3. Click Start to enter the **deployment phase** (see "Match Flow"); when deployment completes the **formal opening** begins automatically.
4. Online battle: the host sets the above options in the room and clicks "Start Game"; the config is pushed to the client and both sides start simultaneously.

## Project Structure

```
.
├── scenes/              Scene files
├── scripts/
│   ├── ai/             AI implementations (heuristic/search/MCTS)
│   ├── core/           Core logic (board/rules/scoring/session/SGF/LocaleManager)
│   ├── effects/        Sound & visual effects
│   ├── net/            Online sync
│   ├── theme/          UI themes (default/cyber/pixel-classic)
│   └── ui/             UI (main menu/game/score panel/replay/board view)
├── sgf/                Built-in game library
│   ├── classic/        Classic games
│   ├── masters/        Master games
│   └── modern/         Modern games
├── tests/              Test suite (1000+ cases)
└── project.godot       Godot project configuration
```

## Running

### From Source

1. Install [Godot 4.7](https://godotengine.org/)
2. Open this project directory with Godot
3. Press F5 or click the Run button

### Quick Start (Windows)

Double-click `StartGame.bat`.

## Testing

The project includes 1000+ automated test cases covering:
- Scoring rules (territory/siege/annihilation/casualties/komi)
- Siege judgment (enclosure/eyes/space)
- Ko rules
- Special forces
- SGF parsing & replay
- Online sync
- AI decisions

Run tests:

```bash
godot --headless --script res://tests/run_all.gd
```

## Rules Document

The full rule book is available in English: [WarHorn-Borderline-Rules_EN.txt](WarHorn-Borderline-Rules_EN.txt) (v6.2).

## Tech Stack

- **Engine**: Godot 4.7 (GDScript)
- **Rendering**: gl_compatibility (cross-platform)
- **Network**: ENet Multiplayer API
- **Architecture**: RefCounted pure logic layer + Control UI layer, easy to test and simulate with AI

## Repository

- Gitee: https://gitee.com/shamdom888/warhorn-borderline
