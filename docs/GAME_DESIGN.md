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

Ground acceleration is based on 250 u/s times the stance factor, whatever weapon you hold, as in CS:GO (D-023).

Starting physics values, CS:GO-like *(tune)*:

| Setting | Value |
|---|---|
| Gravity | 800 units/s² (20.3 m/s²) |
| Ground acceleration | 5.5 |
| Friction | 5.2 |
| Stop speed | 80 units/s |
| Air acceleration | 12 |

**Body:** 1.83 m tall (72 units), eyes at 1.63 m (64 units), 0.8 m wide.

**View:** CS's default field of view, 90° horizontally on a 4:3 screen. Widescreen shows more at the sides, as in CS.

**Units:** 1 Godot unit = 1 metre. CS values are converted with 1 Source unit ≈ 2.54 cm, which makes the 72-unit-tall CS player about 1.83 m tall.

**Skills the movement must support:** counter-strafing (tapping the opposite key to stop instantly), jiggle peeking and crouch-jumping onto boxes.

**Crouch-jump:** crouching in the air pulls your legs up, so press crouch while airborne, or together with jump. This raises your feet from 57 to 75 units, enough to land on a 64-unit crate.

**Measured** (by `tests/movement_test.gd`, holding the Rifle):

| Check | Result |
|---|---|
| Run / walk / crouch top speed | 215 / 112 / 73 u/s (250 / 130 / 85 with nothing in hand) |
| Time to drop below 34% speed (accurate shooting) | 70 ms counter-strafing, 203 ms releasing the key |
| Standing jump / crouch-jump, feet height | 57 u / 75 u |
| Speed you can add sideways in the air | 0.76 m/s (30 u/s) |
| Bunny-hop cap | 1.2 × run speed (6.55 m/s with the Rifle) |

### 4.2 Shooting

- **Hitscan:** bullets hit instantly along a straight line, with no travel time, like in CS.
- **Accuracy:**
  - The first shot is accurate when you stand still.
  - Inaccuracy grows with movement speed, jumping and sustained fire. Crouching reduces it.
  - Each automatic weapon has a fixed, learnable **spray pattern** plus a little random spread.
  - Recoil recovers over time once you stop shooting.
  - **How recoil works in Chiip:** each shot's position in the spray pattern pushes it away from your aim. The view kicks by half of that (aim punch), so while spraying the bullets land above the crosshair and you pull down to compensate. After you stop, the pattern wears off at 12 shots per second (starting 0.15 s after the last shot): a 3-shot burst is gone in about 0.4 s, a full 30-shot spray in about 2.6 s. Checked: shots follow the pattern exactly (0.0000° off with random spread switched off).
  - Shots land at a random spot inside a cone around your aim. The distance from the center is uniform (as in CS), so on average shots land halfway out and most hit near the middle. Measured with 20 taps each: standing 0.057° average / 0.115° worst (cone 0.12°), running 2.5° / 4.4° (cone 4.6°).
- **Damage by hit zone** (CS-like multipliers *(tune)*):

  | Zone | Multiplier |
  |---|---|
  | Head | ×4 |
  | Chest and arms | ×1 |
  | Stomach | ×1.25 |
  | Legs | ×0.75 |

- **Measured with the Rifle** (one shot per zone at a dummy):

  | Zone | 5 m | 40 m |
  |---|---|---|
  | Head | 142.9 | 135.2 |
  | Stomach | 44.7 | 42.2 |
  | Chest / arms | 35.7 | 33.8 |
  | Legs | 26.8 | 25.3 |

  A headshot kills an unarmored player (100 HP) at any distance on the range. Damage is shown rounded down, as in CS.
- **Armor** reduces body damage, and a **helmet** reduces headshot damage. Bought from M7 on; until then nobody has armor (D-041).
- Later (backlog): wallbangs (shooting through thin surfaces) and tagging (getting hit slows you down).

### 4.3 Weapons

Weapons get their own names in Chiip. CS names are used here only as a reference. Weapon stats are stored in data files (`weapons/*.tres`), so they're easy to compare and tune.

**Rifle** (working name, AK-like), starting values *(tune)*:

| Stat | Value | CS AK-47 reference |
|---|---|---|
| Damage | 36, ×0.98 per 500 units of distance | 36, 0.98 |
| Headshot | 144 at point-blank: kills an unarmored player in one shot | 143 |
| Fire rate | 600 rounds/min | 600 |
| Magazine | 30 + 90 | 30 + 90 |
| Reload | 2.5 s | ~2.5 s |
| Speed while held | 215 u/s | 215 |
| Accuracy (cone radius) | 0.12° standing, 0.08° crouched, +4.5° at full run, +9° in the air, +0.1° per spray shot (max +1.5°) | — |
| Spray | 30-shot pattern: climbs ~6° over 10 shots, sways left to −2.3°, then right to +1.95° | Similar shape |
| Aim punch | The view kicks 50% of the pattern; recoil wears off at 12 shots per second | ~50% |

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
- **Difficulty** comes from reaction time, aim accuracy, spray control and decision speed. Presets *(tune)*:

  | | Easy | Normal | Hard |
  |---|---|---|---|
  | Noticing speed | 1.5× slower | baseline | 0.7× |
  | Reaction time (after noticing) | 0.6 s | 0.45 s | 0.3 s |
  | Max turn speed | 150°/s | 220°/s | 320°/s |
  | Aim error (start → smallest wobble) | 10° → 2° | 8° → 1.1° | 5° → 0.8° |
  | Headshot chance | 5% | 15% | 35% |
  | Recoil control | 10% | 50% | 65% |
  | Counter-strafes before shooting | no | yes | yes |

  *Noticing*: an enemy must stay in view for a moment before a bot reacts: 0.25 s + 1 s per 35 m, 2.5× longer outside the central 50° of its vision (D-037). Measured for Normal: 0.50 s at 10 m straight ahead, 1.31 s at 40 m, 1.11 s at 10 m at the edge of vision.

  Measured against a player standing still at 10 m with the bot holding an angle (3 runs each, after the M4 playtest tuning): first shot after ~1.4 / ~0.95 / ~0.6 s, kill after ~4.3 / 2–4 / 1.1–1.5 s. A moving target is much harder for them.
- **States:** patrol → engage (enemy noticed) → search (walk to the last known position, look left, right and ahead) → patrol. Hearing you run, or being shot, makes a bot come and check. A bot can also *hold* a position (watch one direction) instead of patrolling.
- **Turning** eases in and out like a hand on a mouse (no constant-speed snapping), so tracking a moving target lags a little.
- **Animation:** procedural walk cycle (legs swing from the hips, arms a little, the body bobs), a placeholder until real animated models (D-039).

### 4.5 Rounds and match

- Two teams **without names** (D-041). Each player sees their own team in **blue** and the enemies in **red**. Underneath, one side attacks and the other defends, which decides where they spawn and who wins on time-out.
- You plus bot teammates vs. a bot team: 1–5 per side, 3v3 by default.
- Round phases *(tune)*: freeze time (5 s; 15 s with buying from M7) → live round (~1:55) → round end (~5 s). During freeze time you can look around but not move or shoot.
- A round is won by eliminating the other team, or through the bomb objective (M8). If time runs out, the defending side wins, as in CS.
- Match: first to **5** (default), **10** or **15** rounds. Sides swap at half time, after 4, 9 or 14 rounds, so a draw is impossible.
- **Spawns:** each side has five spawn points at its own end of the map. On the test map the defenders start at the north end behind the peek walls and the attackers at the south end of the range, 112 m apart.
- Friendly fire is a match setting: off by default; when on, teammates take a third of the damage, like CS competitive. With it off, bullets pass through teammates (as in CS), so a teammate walking through your spray doesn't block it.

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

- **Your own footsteps** are clearly audible (−12 dB), so you always know when you're making noise, but quieter than enemy steps.
- **Enemy footsteps** are loud and directional and fade out at 30 m, a bit beyond the 25 m at which bots hear you. Hearing is symmetric: you can hear them as far as they can hear you (D-038).
- **Footsteps are bright** (most energy around 1–6 kHz), so they carry on laptop speakers too.
- Walking (Shift) and crouch-walking are silent for everyone.

## 5. Look and feel

The target is the era of Quake (1996) and Counter-Strike 1.x (1999–2003).

- Low internal render resolution, upscaled crisply so pixels stay sharp.
- Pixelated textures with nearest-neighbor filtering, so no smoothing.
- Simple geometry: blocky architecture and low-poly models.
- World image limited to 12 shades per color channel with ordered dithering (D-030).
- Lighting: cool daylight (D-031): neutral white sun, long shadows, light grey-blue haze, warm accents only from lamps and wood. Deliberately *not* a desert/dust look, so Chiip doesn't read as a Counter-Strike copy. Baked lightmaps are being evaluated in M3.
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
- Crosshair style: size, gap, thickness, color and center dot, like CS crosshair settings. Built in M2 (`ui/crosshair.gd`); the defaults are green, 7 px lines, a 4 px gap, 2 px thick, outlined, no dot, static (D-021). Dynamic mode widens the gap to match the actual inaccuracy cone, e.g. +38 px at 720p for 4.5°.
- Later: viewmodel (weapon) position.

## 8. Out of scope for now

Matchmaking, ranked mode, skins and cosmetics, mobile.

Multiplayer *is* planned, as M9 after the single-player game: one player hosts, friends join and bots fill empty slots (D-033).
