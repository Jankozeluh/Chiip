# Chiip: known issues

> What doesn't work yet or hasn't been checked, for v0.2.0 (updated from the v0.1 list by the release preparation). Reported bugs go to the GitHub issues, or use **Report a bug** in the pause menu. The test plan is [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md).
>
> Last updated: 2026-10-17

## Builds

- **The builds are not signed.** Windows SmartScreen and macOS Gatekeeper warn the first time; the README says how to get past it.
- **The Windows and Linux builds are exported on a Mac.** They have not been run on real Windows or Linux computers by the author yet (their data was checked to be complete, but nobody has played them), so graphics-driver problems are possible there. Please report them with your graphics card and driver.
- The Windows `.exe` has Godot's default icon (a custom one needs an extra tool).

## Online play

- Games on the same network list themselves on the Join page (the game browser), but **over Tailscale you paste the host's address once** (Tailscale doesn't carry that announcement between devices); the hosts you joined are then kept under *Recent*. There is no server list on the internet.
- The host plays too: there is no dedicated server, so the match ends for everyone when the host quits, and the host's connection decides how good it is for the others.
- Everyone must run the same version of the game.
- **A friend is trusted only so far.** The host checks and limits everything a friend's computer sends (a broken one can't crash or flood it), but it can't tell an aim bot or a lag switch from a good player: play with people you invited.
- **The game does not encrypt its traffic.** Tailscale does (WireGuard); on a LAN or through a forwarded port the packets are readable by others on the path. Another reason to use Tailscale.
- Internet play is meant to go through Tailscale (see the README). Other ways to reach the host (a forwarded port on the router) work but aren't supported.
- **Joining through a real Tailscale address has been tested only in its parts** (the address list, the copy button, joining through a LAN address between real game processes). The first real join between two computers on a tailnet is part of the playtest.
- A join to an address where no game runs now ends with a message after 10 seconds (it used to wait for half a minute).

## Window, input and platforms

- Fullscreen and window resizing are checked by an automated layout test at seven window sizes, not by a person on each system.
- On a Mac, Ctrl + click may count as a right click (a macOS habit); if crouching with Ctrl misbehaves, rebind Crouch under Settings → Controls. Not confirmed either way yet.
- **Gamepad support is new** and was checked mostly with automated tests (simulated buttons and sticks): please report a controller that misbehaves, with its name.
- English only (a Czech translation was dropped).

## Game

- All sounds and the music are generated ones, and their mix was set by measurement; tuning by ear is still to come. Sound through doorways (a path, not just walls) is not done.
- Bots call out enemies and trade kills now, but they don't take a bomb site together, and how a round goes varies from game to game.
- Only three small maps and one bomb scenario (the map vote at the end of a rotation chooses among those three). Community maps are welcome (CONTRIBUTING.md).
- Stats are kept on your computer only, with no charts over time yet, and the aim trainer has flick targets only (no tracking target). The killcam plays in Team Deathmatch and free-for-all, not in Bomb.
