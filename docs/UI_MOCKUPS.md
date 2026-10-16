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

## How a mockup becomes the game

*Added by the M10 UI work (D-130, D-131). Your mockups are the source of truth: each one is applied screen by screen, with before/after screenshots.*

1. **Colours, sizes and spacing → tokens.** Every visual value of the UI is a named token in `tools/ui_palette.gd`: colours (`PANEL`, `BUTTON`, `ACCENT`, `TEXT_DIM`...), the fonts (`FONT`, `FONT_BOLD`), text sizes (`TEXT_SIZE` 16, `TEXT_SIZE_LARGE` 32, `TEXT_SIZE_TITLE` and `TEXT_SIZE_HERO` 48), line widths (`BORDER`, `LINE`), paddings and gaps. A mockup's hex colours and pixel sizes (at 1280 × 720) go there; then the theme tools run (CLAUDE.md, Commands) and every screen changes at once.
2. **Shapes → the theme tool.** Whether a button has a frame, a panel a border, a tab an underline is decided in `tools/make_ui_theme.gd`, per *role* (a type variation). It has no numbers of its own; it only says which token goes where.
3. **Layout → the scene.** Where things sit on a screen (columns, order, alignment, what is shown) is in the screen's `.tscn`. Screens pick roles and never set a colour or size of their own, so a layout change doesn't touch the look and the other way round.
4. **Icons → their slots.** A PNG named after its slot in `assets/ui/icons/` (list in `ui/ui_icons.gd`: `rifle`, `carbine`, `smg`, `shotgun`, `sniper`, `pistol`, `hand_cannon`, `knife`, `frag`, `flashbang`, `smoke`, `armor`, `helmet`, `defuse_kit`, `bomb`, `rifleman`, `bulwark`, `marksman`, `scout`, `headshot`, `health`) appears wherever the screens ask for it; until then they show text.
5. **Check:** `tools/ui_screenshots.gd` pictures every screen through the real game at 720p or 1080p, before and after.

| # | Mockup | Scene (layout) | Roles it uses today |
|---|---|---|---|
| 0 (01 Boot) | Boot screen | `ui/boot_screen.tscn` (+ `.gd`) | `InkPanel`, `LoadingColumn`, `HeroLabel` (the game's name while the logo file is missing), `ChipRow` of `TextChip` / `LineChip`, `MuteLabel`. Built (D-153); the logo file `assets/ui/studio_logo.png` is yours to add |
| 1, 2 | Main menu | `ui/main_menu.tscn` (+ `.gd`) | `SidePanel`, `LogoLabel`, `FriendlyChip` / `EnemyChip` / `AccentChip`, `ChipRow`, `ModeList` of `BigButton` menu items (chip icon), `DividerMargin` + `LineSeparator`, `SmallItemButton`, `MuteLabel`, `ShadowLabel`. Built (D-135) |
| 2 | Play screen (mode choice + Custom) | `ui/match_setup.tscn` (+ `.gd`, cards and rows built in code) | `InkPanel`, `PageMargin`, `PageColumn`, `TitleLabel`, `DimKeyCapLabel`, `TextButton`, `CardRow` of `ModeButton` / `ModeButtonPicked` cards (`ModeMargin`, `ModeText`, `ModeTitleLabel`, `TagLabel`, `ModeDetailLabel`, `HeaderLabel` / `MuteLabel`), `FormGrid` rows (`RowBox`, `DimLabel`, `SegmentFrame`, `SegmentRow`, `SegmentButton`, team chips `FriendlyChipButton` / `EnemyChipButton` / `EmptyChipButton` in `TeamChipRow`), `BigPrimaryButton`. Built (D-135) |
| 3 | Class draft | `ui/class_menu.tscn` today (M7 turns it into the draft) | `ModalPanel`, `PanelMarginWide`, `ContentBox`, `TitleLabel`, `FormRow`, cards: `PanelContainer` with `PanelMargin`, `HeaderLabel`, `BrightLabel`, `DimLabel` |
| 4, 5 | HUD (Team Deathmatch, Bomb) | `ui/hud.tscn` (health, ammo, weapon, death and spectate lines), `ui/round_hud.tscn` (top bar, centre messages, respawn countdown, kill feed), `ui/bomb_hud.tscn`, `ui/crosshair.gd` | `HUD_*` tokens; `HudValueLabel`, `HudWeaponLabel`, `HudDeathLabel`, `HudSpectateLabel`, `HudRespawnLabel`; top bar `HudTopBar`, `HudFriendlyBox` / `HudTimerBox` / `HudEnemyBox`, `HudBoxMargin`, `HudBoxContent`, `HudScoreLabel`, `HudTimerLabel`, `HudRoundLabel`, `HudPips`; messages `HudMessages`, `HudTitleLabel`, `HudLineLabel`, `HudNoteLabel`; bomb `HudBombTagLabel`, `HudPromptLabel`, `HudBombMessageLabel`, `HudBarBack` / `HudBarFill`; state colours and the pip size in the theme type `Hud`. Armor, weapon slots, money and pickups come with M7 |
| 6 | Buy menu | M7 (`m7-arsenal` branch) | built on the same roles |
| 7 | Tab scoreboard | `ui/scoreboard.tscn`, `ui/scoreboard_table.gd` (rows built in code) | `OverlayPanel`, `PanelMargin`, `ContentBox`, `DimLabel`, `ScoreRow`, `FriendlyScoreLabel` / `EnemyScoreLabel`, `TableBox`, `TeamBox`, `TeamHeaderFriendly` / `TeamHeaderEnemy`, `RowPanel` / `YouRowPanel`, `RowMargin`, `BrightLabel`; dead rows dimmed by `Palette/dead_row` |
| 8 | Match-end screen | `ui/match_end_screen.tscn` (+ the same table) | `BackdropPanel`, `ModalPanel`, `VictoryLabel` / `DefeatLabel`, `FriendlyScoreLabel` / `EnemyScoreLabel`, the table's roles, `ButtonRow` |
| 9 | Pause menu | `ui/pause_menu.tscn` | `BackdropPanel`, `ModalPanel`, `PanelMarginWide`, `ContentBox`, `TitleLabel`, `BigButton` |
| 10 | Settings | `ui/settings_menu.tscn` (+ `.gd`, rows built in code), crosshair preview `ui/crosshair.gd` | `BackdropPanel`, `ModalPanel`, `SwatchRow`, `SwatchMargin`, `TitleLabel`, `TabContainer`, `FormRow`, `HeaderLabel`, `DimLabel`, `InsetPanel`, `HSlider`, `LineEdit`, `CheckBox`, `OptionButton`, `Button` |
| 11 | Multiplayer lobby | M9 (`m9-multiplayer` branch); its entry goes in the main menu's `Links` row | built on the same roles |
| 12 | Kill feed lines | `ui/kill_feed.gd` (lines built in code) | after M7 is merged (it adds the weapon icons) |
| 13 | Developer console | `ui/dev_console.tscn` | `ConsolePanel`, `ConsoleLabel`, `ConsoleLineEdit` (monospace `FONT_MONO_NAMES`) |
| 14 | Loading / map change | doesn't exist yet | new scene when the mockup arrives |
| 15 | Toasts and alerts | `ui/round_hud.tscn` (centre messages), `ui/bomb_hud.tscn` | HUD roles |
| 16 | Icons | `assets/ui/icons/` | the slots above |
