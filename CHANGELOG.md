# Changelog

Every release of Chiip, newest first. The section of a version is the text of its GitHub Release (`docs/RELEASING.md`), and the website's Updates page shows it. Versions follow `config/version` in `project.godot`.

## [0.2.0] - 2026-10-17

**Free-for-all, a killcam, a game browser and chat, stats and training, real sound, and gamepad and colour-blind options.**

**Created by JK · Divocakos.** © Divocakos.

### New

- **Free-for-all**: everyone for themselves, first to the kill limit wins (a card on the Play screen, next to Team Deathmatch, Bomb and Practice).
- **Killcam**: after a death in Team Deathmatch or free-for-all, the last seconds through your killer's eyes. **Space** skips it; Settings → Game turns it off.
- **Playing with friends**: games on your network list themselves on the Join page (the game browser), the hosts you joined are kept under *Recent*, **text chat** works in the lobby and in a match (**Enter** to type, **Esc** to cancel, host-checked and plain text), and at the end of a rotation everyone **votes for the next map**.
- **Stats**: a Stats screen with K/D, ADR, headshot %, accuracy per weapon, wins per mode and map and your last 100 matches, saved on your computer only (with an export to CSV and a reset).
- **Training** on the Shooting Range: an **aim trainer** (30, 60 or 90-second runs of flick targets, with a best per gun) and a **spray wall** that draws the held gun's pattern against your own bullet holes.
- **Sound**: every gun has its own close and far shot and its own reload; sound is **muffled through walls** and rings differently in yards, rooms and halls; menu music and round stingers; a music volume setting.
- **Gamepad**: any controller, with button prompts that follow the device you used last, rebindable in Settings → Controls (a *Pad* column).
- **Colour-blind-safe team colours** (Settings → Video: blue and orange), a **compass** with callouts, a **UI scale** setting, and an FPS counter and developer overlay on **F3**.
- **Wallbangs**: bullets go through thin cover and lose damage by material; bots that hear you behind thin cover may spray through it.
- **Smarter team bots**: they call out the enemies they spot and trade the death of a teammate.
- **New menus**: the Settings, Stats, Credits and boot screens follow a new design (new Interface and Controller tabs in Settings).
- **Bug reports**: **Report a bug** in the pause menu (or `bug_report` in the console) packs the game's log, version and settings, without your address, into a zip and opens its folder.

### Fixed

- Picking the colour-blind colours froze the game for several seconds.
- Bots that stopped fighting in online Team Deathmatch.

### Update

Download 0.2.0 and use it instead of 0.1.1. Your settings are kept (unzip the new version anywhere and start it); the new stats file and logs are made on first use. For an online game **everyone should update**: play with friends on the same version.

### Download

| System | File |
|---|---|
| Windows 10 or newer, 64-bit | `Chiip-0.2.0-windows-x86_64.zip` |
| macOS 11 or newer, Apple silicon and Intel | `Chiip-0.2.0-macos-universal.zip` |
| Linux, 64-bit, with a Vulkan driver | `Chiip-0.2.0-linux-x86_64.zip` |

The builds are **not signed**, so your system warns you the first time; the [README](https://github.com/Jankozeluh/Chiip#download-and-run) says how to get past it. Each release has a `SHA256SUMS.txt` with the checksum of every zip (the README says how to check yours).

### Known issues

See [KNOWN_ISSUES.md](https://github.com/Jankozeluh/Chiip/blob/main/docs/KNOWN_ISSUES.md). The Windows and Linux builds were made on a Mac and have not been tried on real Windows or Linux computers by the author; please report problems with your graphics card and driver. The gamepad support and the sound mix are new and have had little testing by hand.

### Licences and credits

Code under GPL-3.0, art, models, maps and sounds under CC BY-NC-SA 4.0; the name Divocakos and the studio logo are all rights reserved. Every download has `LICENSE`, `LICENSE-ASSETS` and `THIRD_PARTY_NOTICES.md` next to the game, and the game shows them under **Settings → Licences**.

## [0.1.1] - 2026-10-16

**A fix for the first public playtest: bullets hit again.**

**Created by JK · Divocakos.** © Divocakos.

In 0.1.0 your bullets went through the enemies and hit the wall behind them, and theirs went through you: nobody could hurt anybody. The downloaded game lost every character's hit zones on the way from the project to the build (a default value in one script made the export drop the boxes' data); playing from the editor worked, so the tests didn't see it. Now every build is checked before it ships: the packaging plays a real shot each way in the exported game and stops if either does no damage.


### Fixed

- **Shots not registering in exported builds** (the downloads of 0.1.0): bullets hit characters again, and the game's tests include a check run against an exported build.

### Update

Download 0.1.1 and use it instead of 0.1.0; nothing else changed, and your settings are kept (unzip the new version anywhere and start it). For an online game everyone should update: a host on 0.1.0 can't hurt anyone, so the host has to be on 0.1.1.

### Download

| System | File |
|---|---|
| Windows 10 or newer, 64-bit | `Chiip-0.1.1-windows-x86_64.zip` |
| macOS 11 or newer, Apple silicon and Intel | `Chiip-0.1.1-macos-universal.zip` |
| Linux, 64-bit, with a Vulkan driver | `Chiip-0.1.1-linux-x86_64.zip` |

Everything else is as in 0.1.0 below: unzip it anywhere and start Chiip, check the zip against `SHA256SUMS.txt`, and get past the unsigned-app warning as the [README](https://github.com/Jankozeluh/Chiip#download-and-run) says.

## [0.1.0] - 2026-10-16

**The first public playtest. Superseded by 0.1.1: in this build shots did not register (bullets went through the characters). Please use 0.1.1.**

**Created by JK · Divocakos.** © Divocakos.

A tactical shooter in the spirit of Counter-Strike, in the look of a 1990s Quake-era game. You and your bot teammates against a team of bots, or with friends online in place of the bots. Free, for Windows, macOS and Linux.

This is the first release that friends can download and play together, so expect rough edges: what we know about is in [KNOWN_ISSUES.md](https://github.com/Jankozeluh/Chiip/blob/main/docs/KNOWN_ISSUES.md). Please tell us what you find.

### Download

| System | File |
|---|---|
| Windows 10 or newer, 64-bit | `Chiip-0.1.0-windows-x86_64.zip` |
| macOS 11 or newer, Apple silicon and Intel | `Chiip-0.1.0-macos-universal.zip` |
| Linux, 64-bit, with a Vulkan driver | `Chiip-0.1.0-linux-x86_64.zip` |

Unzip it anywhere and start Chiip. Each release has a `SHA256SUMS.txt` with the checksum of every zip (the README says how to check yours). The builds are **not signed**, so your system warns you the first time; the [README](https://github.com/Jankozeluh/Chiip#download-and-run) says how to get past it in a few clicks (Windows: *More info → Run anyway*; macOS: right-click → *Open*, or *System Settings → Privacy & Security → Open Anyway*; Linux: `chmod +x Chiip.x86_64`).

### What is in it

- **Two modes, on three maps:** **Bomb** (CS-style rounds: buy in the freeze time, plant or defuse, first to 5 rounds with a side swap) and **Team Deathmatch** (respawning, first to the kill limit), on **Depot**, **Square** and **Spillway**, alone or in a rotation. **Practice** on the **Shooting Range**, with targets at every distance, a stand for every gun and bots on demand.
- **Teams of 1 to 5 a side**, you included, with bot teammates and bot enemies on three difficulties (Easy, Normal, Hard).
- **Four classes**, two offered at random each match, each with its own perk and loadout: Rifleman, Bulwark, Marksman, Scout.
- **A full arsenal and a light economy:** Ram (rifle), Warden (carbine), Hornet (SMG), Breaker (shotgun), Heron (sniper), Sparrow (pistol), Verdict (hand cannon), a knife, and Frag, Flashbang and Smoke grenades; armor, helmets and defuse kits; guns on the floor to pick up.
- **CS-style movement and shooting:** counter-strafing, bunny-hop cap, a spray pattern you can learn, headshots, wall-aware first-person guns.
- **Online with friends** by IP address, built for **Tailscale** (nothing to open on your router): one player hosts and plays, friends join, bots fill the empty slots. The host's lobby shows the Tailscale address to share, with a Copy button. The README has the step-by-step.
- **A retro look made for Chiip:** pixel-art menus (Silkscreen font), a map kit with textures, props and lamps, and a palette effect. Everything is adjustable: sensitivity (in CS units), field of view, crosshair, key bindings, video and audio, and a UI scale.
- **Any window size and fullscreen:** the UI scales to fit.
- **Maps from the community** will ship in later releases: they are curated in the repository, see [CONTRIBUTING.md](https://github.com/Jankozeluh/Chiip/blob/main/CONTRIBUTING.md).

### Playing with friends in a minute

1. Everyone installs [Tailscale](https://tailscale.com/download); the host shares their computer with each friend from the Tailscale admin console (*Machines → ⋯ → Share…*).
2. The host starts Chiip → **Host**, clicks **Copy** next to the Tailscale address and sends it to the friends.
3. Friends: **Join** → paste → **Join**. The host presses **Start**.

Everyone must run the same version of the game. If it won't connect, the README has a short list of things to check.

### Known issues

See [KNOWN_ISSUES.md](https://github.com/Jankozeluh/Chiip/blob/main/docs/KNOWN_ISSUES.md). In short: the builds are unsigned; the Windows and Linux builds were made on a Mac and have not been tried on real Windows or Linux computers yet; the sounds are simple; the bots are not smart in team tactics.

### Licences and credits

- Code: **GPL-3.0**. Art, models, maps and sounds: **CC BY-NC-SA 4.0**. The studio's name, "Divocakos", and its logo are **all rights reserved** and not part of those licences. Made with the Godot Engine (MIT), the Silkscreen font (OFL 1.1) and FuncGodot (MIT).
- Every download has `LICENSE`, `LICENSE-ASSETS` and `THIRD_PARTY_NOTICES.md` next to the game, and the game shows them under **Settings → Licences**.

### How it was made

Chiip is written in GDScript for Godot 4.7.2, milestone by milestone, with automated tests for the rules, the bots, the maps, the menus and the network code (35 test suites, over 1,100 checks, all passing for this release), plus a script that plays an online match between real game processes. The design, the decisions behind it and the roadmap (sound design, stats and training, accessibility) are in the repository's `docs/` folder.
