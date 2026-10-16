# Chiip — design handoff for v0.2

> Last updated: 2026-10-16
>
> What we still need from the designer. The first round (Foundations, Menus, Match, Icons, World in Claude Design) is built into the game. Since then, several things were built **without a design**, in the existing style. They need a design pass, or a review, before v0.2.

## Ground rules (same as the first round)

The full rules are in [UI_MOCKUPS.md](UI_MOCKUPS.md). In short:

- **Canvas:** 1280 × 720. The game scales it to any window, including 21:9 ultrawide and 16:10. A UI scale setting (Auto, 50–100 %) now exists, so keep layouts anchored to the edges or the centre.
- **Font:** Silkscreen at 16, 32 and 48 px.
- **Colours:**
  - blue is always *your team* and red is always *the enemy*
  - a colour-blind option swaps them for **dark blue / light orange**, so designs must still work with those
  - one accent colour
- **Style:** flat and crisp, hard 1–2 px outlines, no blur or soft shadows.
- **Deliver:** a PNG per screen at 1280 × 720, plus colours (hex), sizes and spacing; or an update to the Claude Design project. Icons as transparent PNGs at their exact pixel size.
- **Credit line:** "Created by JK · Divocakos". The studio logo and name are all rights reserved.

## Priority 1: needed for v0.2

1. **App icon.** The game still shows the default Godot icon. We need:
   - a master at 1024 × 1024, readable at 16 × 16
   - it's then exported as the macOS .icns, Windows .ico (256 px) and Linux PNG (512 px)
   - a favicon for the website
2. **Stats screen** (built by the developers, not designed; opened from the main menu). It needs:
   - a lifetime overview: K/D, ADR, headshot %, accuracy, wins and losses
   - accuracy per weapon
   - wins per mode and per map
   - a match history list, and a match detail view (your line for that match)
   Simple bars or sparklines are welcome, but keep it readable.
3. **Shooting Range training:**
   - **Aim trainer:** the start panel (Start, best score), the HUD during a run (timer, hits, score), and the results panel (score, accuracy, a new best).
   - **Spray practice:** how the weapon's spray pattern shows next to your shots on the wall, and the reset prompt.
4. **Gamepad button prompts:** a glyph set for Xbox, PlayStation and generic controllers. That covers face buttons, bumpers, triggers, both sticks (incl. click), the D-pad, and Start/Select. Sizes 16 and 32 px, in the icon style. Used in hints and the Controls tab.
5. **Settings additions** (rows exist, not designed):
   - UI scale
   - Team colours (normal / colour-blind)
   - gamepad options (look sensitivity, dead zone, invert)
   - music volume
6. **FPS counter and debug overlay** (F3; today a plain developer readout). Two levels:
   - **For players** (like CS's net graph or show-FPS): a small, unobtrusive corner block with FPS, frame time and, online, ping and packet loss. It can stay on during play.
   - **For developers:** the full readout, with speed, position, stance, weapon inaccuracy and recoil, the last hit's zone and damage, and a small frame-time graph.
   Both must stay readable over any background.
7. **Reviews of things built in your style without a design:**
   - **The compass:** a thin strip at the top with N/E/S/W, and red marks where enemies shoot.
   - **The boot screen** with the Divocakos logo. We'd also like logo variants: large for the boot screen, small and single-colour for the menu footer.
   - **The licences / credits screen.**
   - **Bot callouts** ("enemy spotted near A"), shown on the compass and in the kill feed.

## Priority 2: nice for v0.2, can follow later

8. **Map thumbnails** for match setup and the loading screen: Depot, Square, Spillway, Shooting Range. 16:9, pixel style.
9. **Class portraits** for the class-draft cards (Rifleman, Bulwark, Marksman, Scout). Today they're plain silhouettes.
10. **Website** (jankozeluh.github.io/Chiip, built by the developers from the palette): a visual pass with a hero image, layout and download buttons.
11. **GitHub social preview** (1280 × 640) and a release banner. Also one piece of key art that the website and the social preview can share.

## How to see the current state

Ask JK for screenshots of any screen above: the developers can capture each one at 1280 × 720 from the current build. Screens 2 to 7 are already playable in the development build.
