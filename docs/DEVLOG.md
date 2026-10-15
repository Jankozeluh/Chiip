# Chiip — Devlog

> One entry per work session, newest at the top: what was done, which decisions were made, and what's next.

## 2026-10-15 — Session 2: M1 project setup & movement

**Done**
- Started git. The first commit holds the M0 planning docs.
- Created the Godot project (`project.godot`, icon, `.gitignore`, `.gitattributes`) and the folder structure from ARCHITECTURE.md. Empty folders contain a `.gitkeep` file so git tracks them.
- Engine settings: Forward+ renderer, Jolt physics, 128 ticks per second with physics interpolation, CS gravity (D-008 to D-011).

## 2026-10-15 — Session 1: Choosing the game

**Done**
- Checked the setup. Godot 4.7.2 (standard edition), git and Homebrew were already installed, so nothing else was needed.
- Chose the game's direction through a round of questions: a 3D CS-style tactical FPS against bots, with a retro Quake look, as an ongoing project built "learn as we go".
- Named the game **Chiip** and created the `Games/Chiip/` folder.
- Wrote the documentation: README, game design, plan (M0–M7), architecture, decision log, learning notes, this devlog and CLAUDE.md.

**Decisions:** D-001 to D-007 in [DECISIONS.md](DECISIONS.md).

**Next:** The user reviews the plan. After that, M1 starts with creating the Godot project and git, then the player movement.
