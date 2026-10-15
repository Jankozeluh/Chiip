# Chiip — Game Design Document

> Living document: it changes as the game is built and playtested. Values marked *(tune)* are starting points, not final numbers.
>
> Last updated: 2026-10-15

## 1. Pitch

Chiip is a single-player tactical first-person shooter in the spirit of Counter-Strike. You fight rounds against bots with precise, learnable gunplay, in a chunky, pixelated world that looks like a 1996 Quake-era shooter.

## 2. Design pillars

Every feature should support at least one pillar. If it doesn't, it goes to the backlog.

1. **Gunplay you can master.** Accuracy is earned by stopping before you shoot, controlling the spray and aiming at heads. Skill from CS should carry over.
2. **Every round matters.** You get one life per round, money carries between rounds, and you decide when to buy and when to save.
3. **Readable retro look.** Low-res and pixelated, but enemies are always clearly visible. Clarity beats detail.
4. **Fair bots.** Bots react with human-like delay, miss sometimes and never see through walls.

## 3. Core loop

Buy during freeze time → play the round (move, hold angles, fight, plant or defuse) → round ends → earn money → next round.

A match is won by the first team to win a set number of rounds.

## 4. Mechanics

### 4.1 Movement

Movement is based on Counter-Strike, which inherited it from Quake: you accelerate and slow down with friction on the ground, and have limited control in the air.

| State | Speed (Source units/s) | Speed (m/s) | Notes |
|---|---|---|---|
| Running with knife | 250 | 6.35 | Top speed depends on the weapon held |
| Running with rifle | 215–225 | 5.5–5.7 | |
| Walking (Shift) | 52% of running | | Footsteps are silent |
| Crouching (Ctrl) | 34% of running | | Better accuracy, smaller target |
| Jump height | ~57 units | ~1.45 m | Big accuracy penalty while in the air |

Starting physics values, CS:GO-like *(tune)*:

| Setting | Value |
|---|---|
| Gravity | 800 units/s² (20.3 m/s²) |
| Ground acceleration | 5.5 |
| Friction | 5.2 |
| Stop speed | 80 units/s |
| Air acceleration | 12 |

**Units:** 1 Godot unit = 1 metre. CS values are converted with 1 Source unit ≈ 2.54 cm, which makes the 72-unit-tall CS player about 1.83 m tall.

**Skills the movement must support:** counter-strafing (tapping the opposite key to stop instantly), jiggle peeking and crouch-jumping onto boxes.

### 4.2 Shooting

- **Hitscan:** bullets hit instantly along a straight line, with no travel time, like in CS.
- **Accuracy:**
  - The first shot is accurate when you stand still.
  - Inaccuracy grows with movement speed, jumping and sustained fire. Crouching reduces it.
  - Each automatic weapon has a fixed, learnable **spray pattern** plus a little random spread.
  - Recoil recovers over time once you stop shooting.
- **Damage by hit zone** (CS-like multipliers *(tune)*):

  | Zone | Multiplier |
  |---|---|
  | Head | ×4 |
  | Chest and arms | ×1 |
  | Stomach | ×1.25 |
  | Legs | ×0.75 |

- **Armor** reduces body damage, and a **helmet** reduces headshot damage.
- Later (backlog): wallbangs (shooting through thin surfaces) and tagging (getting hit slows you down).

### 4.3 Weapons

Weapons get their own names in Chiip. CS names are used here only as a reference. Weapon stats are stored in data files, so they're easy to compare and tune.

| Slot | Role | CS reference |
|---|---|---|
| Knife | Melee, fastest movement | Knife |
| Pistol | Default sidearm | Glock / USP |
| Rifle | Main automatic weapon, one-tap headshots | AK-47 / M4 |
| Sniper | One-shot body kill, slow, scoped | AWP |
| Grenades | High explosive, flash, smoke | HE / flashbang / smoke |

### 4.4 Bots

- Find their way around the map using a navigation mesh.
- Behaviour states: patrol or move to the objective → engage an enemy → search the last known position. Planting and defusing come later.
- **Vision:** a field-of-view cone plus a line-of-sight check, so no wallhacks.
- **Hearing:** running footsteps and gunshots reveal your position. Walking is silent.
- **Difficulty** comes from reaction time, aim accuracy, spray control and decision speed.

### 4.5 Rounds and match

- Two teams: attackers and defenders. Names are still to be decided.
- It starts as the player against bots (1 vs N). Later it can be 5v5 with bot teammates.
- Round phases *(tune)*: freeze time and buying (~15 s) → live round (~1:55) → round end (~5 s).
- A round is won by eliminating the other team, or through the bomb objective (Milestone 7).
- Match: first to 13 rounds wins, like CS2, with a side swap at half time. Shorter formats are available for quick games.

### 4.6 Economy

- Money is earned for round wins, round losses (with a loss bonus that grows), kills and objective actions.
- A buy menu is available during freeze time, inside the buy zone.
- Values are modeled on CS *(tune)*.

### 4.7 Bomb mode

- Attackers carry the bomb to one of two bombsites and plant it, which takes a few seconds.
- Defenders defuse it, faster with a defuse kit.
- A planted bomb explodes after ~40 s *(tune)*.

### 4.8 Audio

In a tactical shooter, sound is part of the gameplay. Footsteps and gunshots must be directional and easy to read. They are retro-styled but clear.

## 5. Look and feel

The target is the era of Quake (1996) and Counter-Strike 1.x (1999–2003).

- Low internal render resolution, upscaled crisply so pixels stay sharp.
- Pixelated textures with nearest-neighbor filtering, so no smoothing.
- Simple geometry: blocky architecture and low-poly models.
- Baked lighting (lightmaps), a dark and moody palette, possibly a limited color palette.
- **Clarity rule:** enemies must always stand out from the background.

## 6. Controls (default)

| Action | Key |
|---|---|
| Move | W A S D |
| Look | Mouse |
| Shoot / scope | Left mouse / right mouse |
| Jump | Space or mouse wheel down |
| Crouch | Ctrl |
| Walk (silent) | Shift |
| Reload | R |
| Weapons | 1 primary, 2 pistol, 3 knife, 4 grenades, 5 bomb |
| Use / defuse | E |
| Buy menu | B |
| Scoreboard | Tab |
| Developer console | ` (backtick / tilde key) |
| Free / capture the mouse | Esc / click |
| Debug overlay | F3 |

Keys are bound by physical position, so they stay in the same place on any keyboard layout (e.g. Czech QWERTZ). All keys will be rebindable. Open question: macOS may treat Ctrl + click as a right click, which would clash with crouch + shoot. This is checked in M1 (see [DECISIONS.md](DECISIONS.md)).

## 7. Settings that matter to CS players

- Mouse sensitivity that matches CS, so your CS sensitivity feels the same.
- Field of view.
- Crosshair style: size, gap, thickness, color and center dot, like CS crosshair settings.
- Later: viewmodel (weapon) position.

## 8. Out of scope for now

Online multiplayer, matchmaking, skins and cosmetics, ranked mode, mobile.

These can be reconsidered later. The code should not make multiplayer impossible.
