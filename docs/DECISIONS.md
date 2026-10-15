# Chiip — Decision Log

> Important decisions: what was decided, why, and what else was considered. Newest entries go at the bottom.
>
> Decisions can be revisited. When one changes, add a new entry that replaces the old one instead of rewriting history, and mark the old one as *Replaced by D-xxx*.
>
> Last updated: 2026-10-15

## D-001 — Engine: Godot 4.7.2 with GDScript (2026-10-15)

**Decision:** Godot 4.7.2, standard edition, scripted in GDScript.

**Why:** It's already installed. GDScript is Godot's main language, with the most tutorials and the tightest editor integration, and needs no .NET setup.

**Alternatives:** C#, which is familiar from Unity but needs the .NET edition of Godot and the .NET SDK, and has fewer Godot examples.

## D-002 — Genre: CS-style tactical FPS, single-player against bots (2026-10-15)

**Decision:** A 3D tactical FPS modeled on Counter-Strike, played single-player against bots first.

**Why:** The user mostly plays CS (1.6, CS:GO, CS2) and Quake. With bots, the game can be built and tested alone, while multiplayer would complicate every system from day one.

**Alternatives:** A Quake-style arena shooter, multiplayer from the start, or a movement and aim playground without enemies.

## D-003 — Art style: retro Quake look (2026-10-15)

**Decision:** Low-res rendering, pixelated textures and simple geometry, in the style of Quake and CS 1.x.

**Why:** It fits the games that inspired Chiip, and simple art is realistic for a one-person hobby project.

**Alternatives:** A plain prototype blockout, or free low-poly asset packs.

## D-004 — Name: Chiip (2026-10-15)

**Decision:** The game is called **Chiip**, and its folder is `Games/Chiip/`.

**Why:** Chosen by the user.

## D-005 — Approach: playable milestones, learn as we go (2026-10-15)

**Decision:** Claude builds the game step by step and explains each new Godot concept, compared to Unity, so the user can make changes themselves. Each milestone ends with something playable. Chiip is an ongoing project, with no fixed end date.

**Why:** The user has Unity experience but is new to Godot, and wants to learn it.

**Alternatives:** Claude builds everything with little explanation, or the user codes and Claude only assists.

## D-006 — Everything is documented (2026-10-15)

**Decision:** A `docs/` folder holds the plan, game design, architecture, decisions, devlog and learning notes. Code has doc comments. The rules for keeping all of it current are in `CLAUDE.md`.

**Why:** The user asked for it. It also lets an ongoing project be resumed easily after a break.

## D-007 — Units and reference values (2026-10-15)

**Decision:** 1 Godot unit = 1 metre. Counter-Strike values are converted with 1 Source unit ≈ 2.54 cm.

**Why:** Metres are Godot's convention, which also keeps physics behaving as expected. Converting CS values gives a familiar feel to start from.

## Open questions

| Question | Decide in |
|---|---|
| Renderer: Forward+, Mobile or Compatibility? | M1 |
| Physics tick rate: Godot's default 60 Hz, or 64/128 like CS servers? | M1 |
| On macOS, does Ctrl + click clash with crouch + shoot? | M1 |
| Low-res rendering approach: window stretch, SubViewport or 3D resolution scale? | M3 |
| Map building: Godot CSG, or TrenchBroom with `func_godot`? | M3 |
| Team sizes: 1 vs N, or 5v5 with bot teammates? | M5 |
| Weapon names | M6 |
| Team names and the game's setting/theme | Any time |
