# Chiip

A tactical shooter in the spirit of Counter-Strike, with the look of a 1990s Quake-era game: you and your bot teammates against a team of bots, bomb rounds or team deathmatch, on three small maps. Play it alone against bots, or with friends online (they take the bots' places). Free, for Windows, macOS and Linux. © Divocakos. Built with [Godot](https://godotengine.org) 4.7.2.

> **Version 0.1.0, the first public playtest.** Expect rough edges; [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md) lists the ones we know about. Tell us what you find.

## Download and run

Get the file for your system from the **[latest release](https://github.com/Jankozeluh/Chiip/releases/latest)**, unzip it anywhere and start Chiip. You need a computer that runs Vulkan games (any graphics card from the last eight years or so) on Windows 10 or newer, a Linux desktop (64-bit), or macOS 11 or newer (Apple silicon or Intel). The game is small and the look is retro, so it runs fast on modest machines.

The builds are **not signed** (a signing certificate costs money every year), so your system shows a warning the first time. That is expected, and this is how to get past it:

**Windows** (`Chiip-…-windows-x86_64.zip`): unzip it, double-click `Chiip.exe`. If Windows SmartScreen says *"Windows protected your PC"*, click **More info**, then **Run anyway**. The first time you host a game, Windows Firewall asks whether to allow Chiip: tick **Private networks** and allow it.

**macOS** (`Chiip-…-macos-universal.zip`): unzip it and drag `Chiip.app` to Applications (or anywhere). The first time, **right-click `Chiip.app` and choose Open**, then **Open** again in the dialog. On recent macOS versions that button may be missing; then open **System Settings → Privacy & Security**, scroll down to *"Chiip was blocked"* and click **Open Anyway**. If macOS says the app *"is damaged"* (it isn't: it is the download's quarantine flag), clear it in Terminal and try again:

```bash
xattr -dr com.apple.quarantine /path/to/Chiip.app
```

The first time you host a game, macOS asks whether Chiip may accept incoming connections: click **Allow**.

**Linux** (`Chiip-…-linux-x86_64.zip`): unzip it, make the file runnable, and start it:

```bash
chmod +x Chiip.x86_64
./Chiip.x86_64
```

If it doesn't start, run it from a terminal to see why; a missing Vulkan driver (Mesa's `mesa-vulkan-drivers`, or your graphics card's) is the usual reason.

Every download has the licences next to the game (`LICENSE`, `LICENSE-ASSETS`, `THIRD_PARTY_NOTICES.md`), and the game shows them under **Settings → Licences**.

## Playing

The main menu offers **Play**, **Practice**, **Settings**, **Quit**, and **Host** and **Join** for online games.

- **Play** opens the Play screen: **Team Deathmatch** (one click on its card starts the match), **Bomb** and **Practice** as cards, and under them **Custom**, the picked mode's options: the map (Depot, Square, Spillway, or the rotation of all three), team sizes (1 to 5 each, you included), the bots' difficulty (Easy, Normal, Hard), the match length and friendly fire. The game remembers your last choices.
- **Team Deathmatch** is respawning: first team to the kill limit (or the most kills when the time is up) wins.
- **Bomb** is CS-style rounds: one attacker carries the bomb; hold **E** inside site A or B to plant it, and defenders hold E next to it to defuse. A match is first to 5 rounds (sides swap at half time), with freeze time to buy (**B**), and money that carries over.
- At the start of a match a **class menu** offers two classes drawn for that match (Rifleman, Bulwark, Marksman, Scout), each with its own perk and loadout. **M** opens it again during freeze time.
- If you die in a round-based match you watch a teammate through their eyes (left click for the next one).
- **Practice** is the Shooting Range: targets at 5, 10, 20 and 40 m, a stand for every gun and grenade, and no bots until you add some with the console (`bot_add [easy|normal|hard] [ally|enemy]`).
- **Esc** opens the pause menu (Resume, Settings, Leave match). Online, the game doesn't pause.

## Controls

| Action | Key |
|---|---|
| Move | W A S D |
| Look | Mouse |
| Jump | Space or mouse wheel down |
| Crouch (crouch in the air to crouch-jump) | Ctrl |
| Walk (silent) | Shift |
| Pause menu (pauses the game and frees the mouse; Esc again resumes) | Esc |
| Capture the mouse again (after alt-tab, with no menu open) | Click in the window |
| Shoot (the knife: slash; a grenade: throw) | Left mouse button |
| Scope in two steps (Heron), stab (knife), lob (grenade) | Right mouse button |
| Next teammate (while dead in a match) | Left mouse button |
| Reload | R |
| Weapons: primary, pistol, knife, grenades (4 again: the next grenade) | 1, 2, 3, 4 |
| Last weapon / drop the gun in hand | Q / G |
| Pick up a gun: walk over it (into a free slot), or look at it and press E to swap | E |
| Buy menu (during the 15 s freeze time; any time in practice): the category's number then the item's, or click | B |
| Plant the bomb (inside a bomb site) / defuse it (next to it), on the quick maps | Hold E |
| Class menu (opens by itself at the start of a match with your two drafted classes; during freeze time, any time in Team Deathmatch and practice mode; then click a card or press 1 or 2, 1 to 4 in practice) | M |
| Scoreboard (in a match: both teams, kills, deaths, assists, damage, who is alive) | Hold Tab |
| Debug overlay (speed, jump peak, inaccuracy, recoil, last hit; hidden at start) | F3 |
| Developer console | Key left of 1 (`` ` ``; on Czech keyboards the key under Esc) |
| Settings menu | **Settings** in the main menu or the pause menu, or type `settings` in the console during a game; Esc or Back closes it (back to the pause menu if you came from there) |

**Console commands:** `help`, `bot_add [easy|normal|hard] [ally|enemy]` (`ally` adds a teammate on your team), `bot_kick [all]`, `bot_difficulty <level>`, `god`, `noclip`, `mp_friendlyfire [0|1]` (teammates hurt each other; off by default, then bullets pass through teammates), `map <name>` (e.g. `map comparison/trenchbroom_room`), `class [name]` (no name: list the classes; with one: take it, in a match during freeze time only), `armor [0-100] [helmet]` (set your armor), `money [amount]` (show or set your money in a match), `clear`, `settings` (opens the settings menu), `disconnect` (leaves the game for the main menu, like CS), and the settings commands (see *Settings* below). Up/down arrows recall earlier commands; the mouse wheel or Page Up / Page Down scroll back through the output.


## Weapons, money and buying

- **Every round starts with the knife and the Sparrow** (a pistol); whatever you buy or pick up lasts that round. Money carries over: $1,000 at the start of each half, $3,000 for a win, $1,500 rising to $3,000 for losses in a row, $200 a kill ($500 with the knife).
- **B** opens the buy menu during the 15 s freeze time (in practice any time, free): the category's number, then the item's, or click.
- **Pick guns up:** walk over one to take it into a free slot, or look at it and press **E** to swap. Each quick map has a **Heron** (sniper rifle) and a **Breaker** (shotgun) on gold rings.
- **Team respawn** has no money: you spawn with your class's loadout.
- The weapons' numbers are in [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md) (4.3, 4.6, 4.10, 4.11) and in the spreadsheet **[docs/weapons.csv](docs/weapons.csv)**, exported from the data files (`tools/export_weapon_table.gd`, see CLAUDE.md).


## Settings

Your settings are saved the moment you change them and apply at once. They live in a text file you can open and edit (with the game closed), `settings.cfg` in Godot's user data folder:

| System | Where |
|---|---|
| Windows | `%APPDATA%\Godot\app_userdata\Chiip\settings.cfg` |
| macOS | `~/Library/Application Support/Godot/app_userdata/Chiip/settings.cfg` |
| Linux | `~/.local/share/godot/app_userdata/Chiip/settings.cfg` |

Open the **settings menu** with **Settings** in the main menu, or by typing `settings` in the developer console (the key left of 1) during a game, or from the pause menu (Esc). It has five tabs, and every change applies and is saved at once, with no Apply button:

- **Game:** mouse sensitivity (CS's scale: a slider and a number field you can type an exact value into), invert Y, field of view (90 across a 4:3 screen, like CS).
- **Video:** fullscreen, V-Sync, frame rate limit, pixel resolution (270 to 720 lines), palette effect, pixelated HUD.
- **Audio:** master, effects and interface volume.
- **Crosshair:** color (swatches or a `#RRGGBB` code), opacity, size, gap, thickness, outline, center dot and dynamic, with a live preview on a dark and a light background.
- **Controls:** click a slot, then press the new key or mouse button (Esc cancels, Backspace clears the slot). Every action has a primary and a secondary slot. A key belongs to one action: if it was in use, the other action loses it and the menu tells you which.

"Reset tab to defaults" puts the tab you are on back. Esc or Back closes the menu. The same settings can also be set from the console; without a value, a command shows the current one:

| Command | What it sets | Default |
|---|---|---|
| `sensitivity [0.05-10]` | Mouse sensitivity on CS's scale (your CS number feels the same) | 1.0 |
| `fov [70-110]` | Field of view the CS way, degrees across a 4:3 screen | 90 |
| `volume [0-1]` | Master volume | 1.0 |
| `fps_max [0\|30-1000]` | Frame rate limit, 0 = unlimited | 0 |
| `settings_reset` | Everything back to its default, key bindings and the remembered match setup included | |

The file also holds Y inversion, fullscreen, V-Sync, the pixel resolution (270, 360, 480, 540 or 720 lines), the palette effect, the pixelated HUD, the effects and interface volumes, the crosshair (color, length, gap, thickness, outline, dot, dynamic) the key bindings (`"key:87"` is the W key, `"mouse:1"` the left button; two per action) and, in a `[match]` section, your last match setup (mode, team sizes, difficulty, match length or kill limit, friendly fire, rotation and map). A value that is out of range is clamped and a missing or unreadable one falls back to the default, so deleting the file, or a line in it, is always safe: **delete `settings.cfg` to start from the defaults**.


## Playing with friends

One player **hosts** and plays, friends **join**, and bots fill the empty slots. Chiip's online play works by IP address and is built for the private network that **[Tailscale](https://tailscale.com)** gives you: nothing is opened on anyone's router, nothing is exposed to the internet, and only the people you invite can connect. (It also works on a LAN, and over any other network where the friends can reach the host's address and **UDP port 26000**.)

### Step by step with Tailscale

Everyone who plays, host and friends, does step 1. The host does 2 and 3, the friends 4.

1. **Install Tailscale** from <https://tailscale.com/download> (free for personal use; Windows, macOS and Linux) and sign in. Check that it says *Connected*.
2. **The host invites friends.** The best way is to share *only the host's computer*, so friends can reach the game and nothing else of yours: open the Tailscale admin console at <https://login.tailscale.com/admin/machines>, find the host's computer, open its **⋯** menu, choose **Share…** and send the invite link to each friend. A friend opens the link, signs in to Tailscale (a free account) and accepts. (You can also invite friends into your whole tailnet under **Users → Invite**, but then they can reach all your devices, so only do that for people you trust with that.)
3. **The host starts the game:** main menu → **Host**. The lobby shows **Friends join at**, with the host's **Tailscale address** (it starts with `100.`) and a **Copy** button. Click **Copy** and send the address to your friends in chat.
4. **A friend joins:** main menu → **Join**. Paste the address into **Join by IP** and press **Join**. Everyone sees the others in the lobby.
5. **In the lobby**, click **Switch team** to pick a side (your team is blue, the other red). The host's **Edit setup** opens the usual match setup (mode, map or rotation, team sizes, bot difficulty, length, friendly fire); empty slots are bots. The host presses **Start** and everyone's game loads.
6. Pick your class in the first freeze time (**M**) as in a game alone. After the match the host chooses **Next map**, **Play again** or **Lobby**; the others can only **Leave**.

Someone who leaves during a match is taken over by a bot ("Name (bot)"); someone who joins a running match takes over a bot of their team. When the host quits, everyone goes back to the menu.

### If it doesn't connect

- **Everyone must run the same version** of Chiip: the host answers "The host runs a different version of Chiip." otherwise.
- Is Tailscale *Connected* on both computers? Try `tailscale ping 100.x.y.z` (the host's address) in a terminal; the first ping may take a moment while the two computers find a direct route.
- The host's firewall must let Chiip in (Windows: *Private networks*; macOS: **Allow** when asked). If you clicked *Deny* by mistake, allow Chiip under *Windows Defender Firewall → Allow an app*, or macOS *System Settings → Network → Firewall → Options*.
- The port is **26000** (UDP) unless the host changed it in the lobby; a friend with a different port types it in the port field next to the address.
- Playing on the same Wi-Fi? The lobby also lists the host's LAN address; use that one for friends in the same house.

### Online commands

Console commands online: `status` (the session, ping, packet loss, prediction corrections, traffic), `net_fakelag <ms>` and `net_fakeloss <percent>` (make your connection worse on purpose, like CS's), `disconnect` (leave; for the host, end the game). Cheats (`god`, `noclip`), `mp_friendlyfire` and `map` only work offline. **F3** shows the same network lines as `status`.

To try online play on one computer, start the game twice: host in one window and join `127.0.0.1` in the other.

## Licences

- The game's **code** is under the **GNU General Public License, version 3** ([LICENSE](LICENSE)).
- The **art, models, maps and sounds** are under **Creative Commons BY-NC-SA 4.0** ([LICENSE-ASSETS](LICENSE-ASSETS)): free to share and adapt for non-commercial use with credit, under the same licence.
- The studio's name, **Divocakos**, and its logo are © Divocakos, **all rights reserved**: they are not covered by the licences above and may not be reused.
- Made with the [Godot Engine](https://godotengine.org) (MIT), the Silkscreen font (SIL Open Font License) and FuncGodot (MIT); see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). The game shows all of it under **Settings → Licences**.

## For developers

Chiip is written in GDScript for Godot 4.7.2 and built milestone by milestone. [docs/DEVELOPING.md](docs/DEVELOPING.md) has how to run it from the editor, run the thirty-three test suites, build maps with TrenchBroom, regenerate the models and textures, and export the builds. The design, the decisions behind it and the roadmap are in [`docs/`](docs/) ([PLAN.md](docs/PLAN.md), [GAME_DESIGN.md](docs/GAME_DESIGN.md), [ARCHITECTURE.md](docs/ARCHITECTURE.md), [DECISIONS.md](docs/DECISIONS.md)). Contributions and bug reports are welcome as GitHub issues.
