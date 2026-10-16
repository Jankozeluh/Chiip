# Chiip — UI mockups to design

> Last updated: 2026-10-16
>
> The list of screens the user designs in Claude Design (D-120). The M10 UI session builds the game's UI from these mockups. Each item says what the screen must contain; how it looks is open.

## Ground rules for every mockup

- **Canvas:** 1280 × 720 (16:9). The game scales the UI by whole steps (2× at 1440p), so design at 1280 × 720, or 2560 × 1440 for a 2× preview. Layouts must also work on an ultrawide 3440 × 1440, so anchor things to the edges or the centre, not to fixed x positions.
- **Font:** Silkscreen (pixel font, Regular and Bold), already in the game. Text sizes 16, 32 and 48 px at 1280 × 720 keep the pixels even. A second font would be a download that needs your OK.
- **Colours:** blue always means *your team* and red always means *the enemy*, in the HUD, kill feed and scoreboard. Keep both clear and use neither for anything else. One accent colour for focus and selection; everything else is yours to choose.
- **Style:** minimal and modern, but pixelated: flat surfaces, crisp edges, generous spacing, a clear hierarchy, few boxes. No soft shadows, blur or gradients, which Godot can't render as pixels; hard 1–2 px outlines and drop shadows are fine.
- **Behind the HUD:** a pixelated 3D world (480 lines), mostly greys, concrete, wood and muted greens. HUD text must read on light and dark backgrounds.
- **What to hand over:** a PNG per screen at 1280 × 720, plus the colours (hex), sizes and spacing if Claude Design gives them. HTML is fine too; it gets translated into Godot's theme and layouts.

## Priority 1: what you see in every match

1. **Main menu.** The game name, Play, Practice, Settings, Quit. Later Host and Join (multiplayer, M9). Something alive behind it: the map flying by, or a still.
2. **Play / mode choice.** Big, simple choices: **Team Deathmatch** (first and the default), **Bomb**, **Practice**. One click to play. A "Custom" panel for map or Rotation, team sizes (1–5 per side), bot difficulty, match length or kill limit, and friendly fire.
3. **Class draft.** At match start you're offered **two random classes** out of four (Rifleman, Bulwark, Marksman, Scout). Each card shows a picture or silhouette, the name, height, role, perk and signature gun, and a key (1 or 2). Also opens in freeze time (M key) to swap between your two.
4. **HUD in Team Deathmatch.** Health, armor, weapon name and ammo (magazine and reserve), crosshair, kills for each team against the kill limit, time left, kill feed, your respawn countdown after you die ("Killed by X · respawning in 3"), and a pickup prompt ("Hold E · pick up SMG").
5. **HUD in Bomb.** Everything from 4 that applies, plus: round timer, score (yours against theirs), players alive per team, freeze-time countdown ("Round 3 · starts in 4"), round-end banner ("Round won" or "Round lost", and why), money, your bomb status (carrying the bomb, plant or defuse progress bar), "Bomb planted" alert, and the spectating line after you die ("Spectating Bot2 · click for next").
6. **Buy menu** (B, during freeze time). Categories: pistols, primaries (rifle, carbine, SMG, shotgun, sniper), gear (armor, helmet, defuse kit), and grenades (HE, flash, smoke). Each item shows its price and icon. Your money, what you already hold, and items you can't afford greyed out. Light economy: few, round prices.
7. **Tab scoreboard.** Both teams (yours on top, in blue), one row per player: name, class icon, kills, deaths, assists, damage. Score or kill count. Dead players dimmed. Your row highlighted.
8. **Match-end screen.** Victory or Defeat, the final score, the scoreboard (as in 7), and buttons: Play again, Next map (in rotation), Main menu.
9. **Pause menu** (Esc). Resume, Settings, Leave match. In online games it doesn't pause the game.

## Priority 2: menus you visit now and then

10. **Settings, five tabs:**
    - Game: sensitivity (slider and number), invert Y, field of view.
    - Video: fullscreen, V-Sync, frame-rate limit, pixel resolution (270–720 lines), palette effect, pixelated HUD.
    - Audio: master, effects and interface volume.
    - Crosshair: colour, opacity, size, gap, thickness, outline, centre dot, dynamic, with a live preview on a dark and a light background.
    - Controls: every action with two key slots ("press a key…").
    Also "Reset tab to defaults" and Back.
11. **Multiplayer lobby (M9).** Host or join: join by IP for LAN, and Steam friends and invites. In the lobby: players per team, team switch, empty slots marked "bot", ready status, the host's match setup (mode, map), and Start (host only).
12. **Kill feed lines in detail.** "Killer > Victim" with a weapon icon and a headshot mark, team colours, and lines that involve you highlighted.

## Priority 3: small but visible

13. **Developer console** (the key left of 1). An output area and an input line.
14. **Loading or map-change screen**, with the map name and mode.
15. **Toasts and alerts:** "Switching sides", "Match point", "Bomb planted", "Low ammo", and a hit marker on a hit.
16. **Icons:** weapons (8: AK-style rifle, carbine, SMG, pump shotgun, sniper rifle, service pistol, hand cannon, knife), grenades (3), armor, helmet, defuse kit, bomb, classes (4), headshot, health. A pixel icon set, probably 16 × 16 or 32 × 32.
