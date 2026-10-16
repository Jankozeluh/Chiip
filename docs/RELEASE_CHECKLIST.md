# Chiip: release checklist

> The test plan for a release (M12, D-178): what is checked by machine, what a person checks, and how. Run it top to bottom before every release; write the result next to each line in a copy of this file (or in the release's issue). The first release is v0.1.0.
>
> Last updated: 2026-10-16

How to read it: **Auto** lines are commands that exit with the number of failures (0 = pass). **Hand** lines are for a person at the keyboard; each says what to do and what you should see. A line that fails goes to GitHub as an issue (steps to reproduce first) or, if it is known and accepted, to [KNOWN_ISSUES.md](KNOWN_ISSUES.md).

`$GODOT` and `$PROJECT` are explained at the top of [DEVELOPING.md](DEVELOPING.md).

## 0. Gates (all automatic, about 5 minutes)

| # | Command | Must show |
|---|---|---|
| 0.1 | `cd "$PROJECT" && bash tools/run_tests.sh` | every suite PASS (44 suites, about 2.3 minutes). `qa` plays every mode on every map, `release` checks the licences, the export presets, the paths, the Tailscale lobby and CONTRIBUTING |
| 0.2 | `bash tools/lan_check.sh` | 4 PASS: a host, a friend who joins and leaves, a second friend who joins the running match, over this computer's LAN address, in three real processes |
| 0.3 | `"$GODOT" --headless --path "$PROJECT" --quit-after 400 -- --no-settings --match` (and `--practice`, `--match --respawn`, `--map res://maps/depot.tscn`, `--match --rotation`) | no `SCRIPT ERROR` line |
| 0.4 | `git status` is clean and `git grep -n -i "<your home folder>"` finds nothing | `release_test` does the second part |
| 0.5 | `bash tools/check_release.sh` (about two minutes; `BUILDS=builds` keeps the builds for step 7) | 9 PASS (M16, D-223): the three release builds export; in each, a shot hurts a bot and a bot's shot you (v0.1.0 shipped without hit zones, D-159; the Windows and Linux builds' game data runs in this Mac's Godot); in the Mac app a full round plays (`--check-round`: the bots walk, a round ends with a winner, the next starts) and two friends join a host (`tools/lan_check.sh` with the app, three processes). `tools/package_release.sh` checks shooting in `builds/macos` once more |

If `tools/run_tests.sh` is run while another copy of the game runs on the same computer, use `TMPDIR=<some folder> bash tools/run_tests.sh` so two runs don't share log files. A test never touches the player's `settings.cfg` (`Settings.real_file_accesses`); another running game may change that file without making a test fail.

## 1. Every mode on every map

Auto: `qa_test` (1.1 to 1.7 in one run: `bash tools/run_tests.sh qa`) starts each of these the way a player does and plays 70 seconds of game time: the right map and rules, 3 against 3, a player who can play, bots that walk and fight, rounds going live or players respawning, nobody falling through the world. `maps_test` plays bot rounds and a respawn match on each quick map.

| # | Mode × map | Hand: start it from the main menu (Play → card → Play) and look for |
|---|---|---|
| 1.1 | Team Deathmatch × Depot | It starts at once (no freeze time), the class menu opens with two classes, the kill feed shows kills, you respawn after 3 s, and the first team to 50 kills (or the time) ends it with the end screen |
| 1.2 | Team Deathmatch × Square | the same |
| 1.3 | Team Deathmatch × Spillway | the same; the low channel is walkable and the bots don't get stuck in it |
| 1.4 | Bomb × Depot | 15 s freeze with the buy menu, the bomb on one attacker, plant at A or B (hold E), explosion or defuse ends the round, sides swap after round 4, first to 5 rounds ends it |
| 1.5 | Bomb × Square | the same |
| 1.6 | Bomb × Spillway | the same |
| 1.7 | Practice × Shooting Range | targets show damage, every stand gives its gun, `bot_add` and `bot_kick` work in the console, you respawn 3 s after dying |
| 1.8 | Rotation (Play screen, map row: Rotation) | after a match the end screen offers **Next map · <name>**; it loads the next map as a fresh match; after Spillway it wraps to Depot |
| 1.9 | End screen | **Play again** restarts the same map; **Main menu** goes back and the menu is usable (no frozen mouse) |
| 1.10 | Leaving | Esc → **Leave match** (and in practice **Leave practice**) returns to the menu; starting another match afterwards works; `disconnect` in the console does the same |
| 1.11 | The three team sizes | 1v1, 3v3 and 5v5 start with the right number of characters; 5v5 stays smooth (the F3 overlay shows the frame rate) |
| 1.12 | The bots' three difficulties | Easy misses and reacts slowly, Hard shoots first; nothing crashes on any |

## 2. Every menu and its flows

Hand, at 1280 × 720 and again fullscreen. Auto: `ui_test`, `layout_test` (every menu at seven window sizes and several UI scales), `ui_screenshots.gd` (see 2.14).

| # | Screen | Do | Expect |
|---|---|---|---|
| 2.1 | Boot screen | Start the game | The Divocakos logo with filling squares for 2.5 s; any key skips; it does not come back after a match |
| 2.2 | Main menu | Click every item; use the keyboard (arrows, Enter) | Play, Practice, Settings, Quit; Host, Join; the focus is visible; "Build 0.1.0 · Divocakos" at the bottom left; Esc does nothing on this page |
| 2.3 | Play screen | Click each card; change every custom row; Esc | One click on a card starts that mode; rows change with the mode; the choices are remembered after a restart; Esc goes back |
| 2.4 | Class menu | Start a match | Two classes are offered; click a card or press 1 / 2; **M** opens it again during freeze time; Esc closes it |
| 2.5 | Buy menu | In a Bomb match, press **B** in freeze time | The category's number then the item's, or click; money goes down; **B** outside freeze time does nothing; practice buys are free |
| 2.6 | HUD | Play a round | Health, armor, ammo and weapon, score and timer, kill feed, the bomb icon on its carrier, the compass |
| 2.7 | Scoreboard | Hold Tab | Both teams, kills, deaths, assists, damage, money; it goes away on release |
| 2.8 | Pause menu | Esc in a game | **Resume**, **Settings**, **Leave match**; the round timer and the bots stop; Esc again resumes; sounds pause |
| 2.9 | Console | Press the key left of 1 | Opens and closes; `help` lists commands; the up arrow recalls; `settings` opens the settings; it doesn't open over a menu |
| 2.10 | Spectating | Die in a Bomb round | You watch a teammate; left click moves to the next; the HUD follows them |
| 2.11 | Match end screen | Finish a match | Victory or Defeat, the score and a scoreboard, **Play again**, **Next map** (rotation only), **Main menu** |
| 2.12 | Loading screen | Start a match | The map's name, the mode and a filling bar; the class draft opens after it, not under it |
| 2.13 | Licences | Settings → **Licences** | The overview with "Created by JK · Divocakos"; each document (code, art, notices, font, FuncGodot, Godot Engine) shows real text, never "not in this build"; Back and Esc return to the settings |
| 2.14 | Screenshots | `"$GODOT" --path "$PROJECT" --resolution 1280x720 --quit-after 20000 --script res://tools/ui_screenshots.gd -- --out <folder>` | 25 pictures; nothing cut off, overlapping or unreadable (also at `--resolution 1920x1080`) |

## 3. Settings: saved, loaded, rebound

Auto: `settings_test`, the rebinding part of `ui_test`.

| # | Do | Expect |
|---|---|---|
| 3.1 | Change something on every tab (sensitivity, FOV, fullscreen, frame limit, pixel resolution, volumes, crosshair, UI scale); quit; start again | Everything is as you left it; the file `settings.cfg` is in the user data folder (README, "Settings") |
| 3.2 | Settings → Controls: click a slot and press a key; press Esc while waiting; press Backspace on a slot | The key is bound; Esc cancels; Backspace clears. A key already in use moves, and the line under the list says who lost it |
| 3.3 | Rebind Shoot, Jump and Crouch; play | The new keys work in the game and the old ones don't |
| 3.4 | **Reset tab to defaults** on each tab | Only that tab goes back; the crosshair previews follow |
| 3.5 | Delete `settings.cfg`, start | The defaults, no error. Put a broken line in the file: the game starts and that value is the default |
| 3.6 | Change a setting from the console (`sensitivity 2`) with the menu open | The slider follows |

## 4. Fullscreen and resizing

Auto: `layout_test` (seven window sizes, a pixelated HUD, a resize while a menu is open, the boot screen).

| # | Do | Expect |
|---|---|---|
| 4.1 | Settings → Video → **Fullscreen** on, then off, in the menu and in a game | The window switches; the UI is whole and in proportion at once; the game keeps going; the mouse is still captured in the game |
| 4.2 | Drag the window to a narrow shape (about 4:3), a wide one (21:9) and a small one | The menus and the HUD stay inside the window and readable; nothing is cut off |
| 4.3 | Settings → Video → **UI scale**: Auto, 50 %, 75 %, 100 % | The UI changes size at once and stays inside the window |
| 4.4 | A second monitor, or a high-resolution screen | The same as 4.1 and 4.2; the pixel resolution setting still gives chunky pixels |
| 4.5 | Alt-tab away and back in a game | The mouse is free while away; a click in the window captures it again; no menu is stuck open |

## 5. Class draft, buying, pickups and the bomb

Auto: `class_test`, `economy_test`, `grenade_test`, `gear_test`, `guns_test`, `bomb_test`, `zone_test`.

| # | Do | Expect |
|---|---|---|
| 5.1 | Start a Bomb match; look at the class menu; pick a class | Two classes out of four, different each match; the pick sticks and its loadout and perk apply |
| 5.2 | Buy a primary, a vest, a defuse kit (defenders) and each grenade | The price is taken; the item appears in the right slot (1 to 4); a second purchase of the same is refused |
| 5.3 | Walk over a gun on the floor; look at one and press E | A free slot takes it; a full slot swaps it; Q and G drop the gun in hand |
| 5.4 | Throw a frag, a flashbang and a smoke | Each behaves (damage, blinding with a whitened screen, a cloud that blocks sight) |
| 5.5 | As an attacker, plant in a site; as a defender, defuse | Holding E fills a bar; leaving the site cancels it; the bomb beeps faster, then explodes or is defused; the round ends accordingly |
| 5.6 | The bomb carrier dies | The bomb drops and anyone on that side can pick it up |
| 5.7 | The economy | $1,000 each half, $3,000 for a win, rising losing bonus, $200 a kill ($500 with the knife) |

## 6. Online: LAN and Tailscale

Auto: `net`, `netplay`, `netjoin`, `netstress`, `netrespawn`, `netarsenal` (in one process) and `tools/lan_check.sh` (three real processes).

| # | Do | Expect |
|---|---|---|
| 6.1 | Two computers on the same Wi-Fi: one **Host**, the other **Join** at the LAN address shown | The friend is in the lobby; Switch team works; the host's **Start** loads both; both play the same match |
| 6.2 | The same through **Tailscale** (README, step by step): the host's lobby shows a `100.` address with **Copy**; the friend pastes it into **Join by IP** | It connects as in 6.1. Check the ping with `status` in the console |
| 6.3 | The friend closes the game in the middle of a round | A bot ("Name (bot)") takes over; the host plays on |
| 6.4 | The friend joins again | They take over a bot of their team and are in the round |
| 6.5 | The host presses Esc, then **Leave** | The friend returns to the menu with "The host ended the game." |
| 6.6 | Two games of different versions | The host refuses: "The host runs a different version of Chiip." |
| 6.7 | A wrong address or a host that isn't there | A clear message on the Join page; **Back** cancels; it doesn't hang |
| 6.8 | A port already in use (host twice) | The lobby says so; nothing crashes |
| 6.9 | The first host on a computer | The firewall question appears (Windows, macOS); after allowing, friends connect |
| 6.10 | `net_fakelag 100` and `net_fakeloss 5` on the client | The game stays playable (prediction); `status` shows the corrections |
| 6.11 | A Team Deathmatch and a Bomb match online to the end | The end screen shows for everyone; the host chooses Next map / Play again / Lobby; the others can only Leave |

## 7. The builds (each platform, from the release zips)

Make the builds only when asked (CLAUDE.md): `BUILDS=builds bash tools/check_release.sh` exports all three and runs the smoke checks of 0.5 on them, then `bash tools/package_release.sh`. Check each zip on its own system where possible; the author has only a Mac, so Windows and Linux need a friend with that computer.

| # | Do | Expect |
|---|---|---|
| 7.1 | Unzip; the folder holds the game, `LICENSE`, `LICENSE-ASSETS`, `THIRD_PARTY_NOTICES.md` | All four |
| 7.2 | Start it (README steps for the unsigned warning) | The boot screen, then the menu; no console window on Windows; the window title is "Chiip" |
| 7.3 | Settings → Licences | Every document shows its text, none says "not in this build" (the include filters work) |
| 7.4 | Play 1.1 and 1.4 for two minutes | Sounds, the fonts, the textures and the models are all there (nothing pink or missing); the frame rate is smooth |
| 7.5 | Practice → console → `map depot`, `map square` | The map list works in an export (it uses `ResourceLoader`) |
| 7.6 | Settings are saved between runs; the file is at the path in the README | Yes |
| 7.7 | Host from the build and join from the editor build (same version) | They connect (6.1) |
| 7.8 | `builds/macos/Chiip.app/Contents/MacOS/Chiip --headless --quit-after 900 -- --no-settings --match` (and `--practice`) | No error. (The test export of 2026-10-16 passed: D-172.) Shooting, a round and a LAN join in the builds are 0.5 |
| 7.9 | File sizes and the zip names | `Chiip-<version>-windows-x86_64.zip`, `…-linux-x86_64.zip`, `…-macos-universal.zip`; each under GitHub's 2 GB limit |

## 8. Before it goes public

| # | Check | Expect |
|---|---|---|
| 8.1 | `release_test` and `netsec_test` | Licence files, presets, no personal path, `.gitignore` entries, CONTRIBUTING, credits, the website and the changelog: all PASS |
| 8.2 | README | Its links work (the release page, the docs, CONTRIBUTING, KNOWN_ISSUES); the download and warning steps match what 7.2 showed |
| 8.3 | `docs/KNOWN_ISSUES.md` and the version's section of `CHANGELOG.md` (the release notes: `bash tools/release_notes.sh <version>`) | Up to date; the notes credit "Created by JK · Divocakos" |
| 8.4 | `git log` and a look at the tree on GitHub after the push | No secrets, no stray files, `builds/` and `.godot/` absent |
| 8.5 | The GitHub Release | v0.1.0 with the three zips and the notes; the download links work from a signed-out browser |
| 8.6 | The website (`site/`, published by the Pages workflow) | Its Download page offers the new version and each system's file (the three buttons end in the right zip), its Updates page lists the notes, its Play and Maps pages read right, and the pages look right on a phone and a wide screen. Routine: [RELEASING.md](RELEASING.md) |

## 9. Security review

Run before every release; the first run was on 2026-10-16 (D-180). Auto lines are in `release_test` and `netsec_test`.

| # | Check | How | Result of 2026-10-16 |
|---|---|---|---|
| 9.1 | **The whole history**, not only the files: no key, token, secret, private e-mail address, sensitive file name or stray big file in any commit that will be public | `python3 -I tools/scan_history.py HEAD` (the branch you publish; `--all` for every branch). Read the notes it prints | **Clean.** No finding in 224 commits. Notes: the old home-folder path of the owner's Mac in about 27 commits and one commit's message-like lines that only mention the word "token" (design tokens); `/home/djrm` is inside FuncGodot's own icon SVG (third-party metadata); every commit has the owner's name and GitHub's no-reply address (accepted, D-176); the biggest file ever stored is a 1.15 MB crew model; the packed repository is 14.7 MiB. Only `main` is pushed: the other branches and the stash stay local |
| 9.2 | **Every RPC has the narrowest mode** and the host checks who sent it | `netsec_test` reads `net/*.gd`: 7 RPCs, the 3 `any_peer` ones (hello, team request, message to the host) each open with `is_host()` and use `get_remote_sender_id()`; the other 4 are `authority` (only the host may call them on a client) | Pass. A message claiming to come from someone else is overwritten with the real sender |
| 9.3 | **The host validates and clamps everything a client sends** | `netsec_test`: commands (finite angles, no impossible yaw or pitch, a slot that exists, and the existing speed budget and queue cap), requests (types, ranges, item id length), session messages (a few short plain entries), names (printable, cut to 16, no direction marks), team requests | Pass: 60 broken, cut, random, oversized, NaN, infinite, nested and wrongly typed packets, requests and messages later the host still runs, the friend's character is whole and nobody was added |
| 9.4 | **Limits and a player cap** | Packets over 8 KB dropped; 400 packets a second, a flood for 3 seconds removes the sender; messages, team requests, requests and hellos limited; a computer that connects and never says hello is removed after 5 s; at most 9 clients plus the host; only introduced players are heard | Pass (a flood of 450 packets a tick: removed after 2.6 s, 1,382 of 147,150 handed on) |
| 9.5 | **No decoding of objects, nothing run from the network** | `netsec_test`: `allow_object_decoding` is false on both sides; no `bytes_to_var_with_objects`, `str_to_var`, `instance_from_id`, `inst_to_dict`, `Expression`, `OS.execute`, spawners or synchronizers in `net/`. Packets use `bytes_to_var` (no objects) | Pass |
| 9.6 | **What stays open** (a friend's computer is trusted only so far) | The host decides hits and checks speed, but a cheating friend can still use an aim bot or a lag switch; the game does not encrypt its traffic: **Tailscale does (WireGuard)**, a LAN or a forwarded port does not, which is one more reason the README sends players to Tailscale; a malformed packet makes the engine print a decode error in the host's log (noise, not a crash); friends should still only play with people they invited | Listed in KNOWN_ISSUES |
| 9.7 | **The website** | The release notes become HTML in one place, after the text is escaped; links only for http(s); the API read is in try / catch and the pages work without it; no inline script, style, handler, frame or form; a content security policy on every page (scripts, styles, pictures and fonts from the site itself, the one connection GitHub's API); nothing from another site. `release_test` and a browser check with a pretend API | Pass |
| 9.8 | **The Actions workflow** | Only `actions/checkout`, `upload-pages-artifact` and `deploy-pages`, each pinned to the full commit SHA of its release (the version in a comment); `permissions:` contents read, pages write, id-token write; no secrets; no `pull_request` or `pull_request_target`; Dependabot proposes updates | Pass |
| 9.9 | **The public repository's settings** | After creating it: `bash tools/harden_repo.sh <owner>/<repo>` (read-only workflow permissions, approval for first-time contributors' workflows, Dependabot alerts and updates, secret scanning with push protection, private vulnerability reporting, no wiki or projects). Add `--protect-main` when friends start sending pull requests (main then takes pull requests only). Read the settings back on GitHub afterwards | Script written and dry-run tested; to run with the owner's OK |
| 9.10 | **The release files** | `bash tools/package_release.sh` writes `SHA256SUMS.txt`; the release includes it; the README tells players how to check; the zips hold only the game and the three notices | Pass (checksums verified with `shasum -a 256 -c`) |
| 9.11 | **The owner's account** | Two-factor authentication on the GitHub account (a passkey or a security key is best): a public repository with releases is only as safe as the account that can publish to it. `gh auth login` in the browser; pushing `.github/workflows/` needs the `workflow` scope (`gh auth refresh -s workflow` if the push is refused) | For the owner |

## Results log

| Release | Date | Done by | Gates 0 | Modes 1 | Menus 2 | Settings 3 | Window 4 | Gameplay 5 | Online 6 | Builds 7 | Public 8 | Security 9 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| v0.1.0 | | | | | | | | | | | | | |
