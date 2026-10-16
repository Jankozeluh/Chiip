# Chiip: known issues

> What doesn't work yet or hasn't been checked, for the first public playtest (v0.1.0). Reported bugs go to the GitHub issues. Written by the pre-release QA pass (M12, D-178; the test plan is [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md)).
>
> Last updated: 2026-10-16

## Builds

- **The builds are not signed.** Windows SmartScreen and macOS Gatekeeper warn the first time; the README says how to get past it.
- **The Windows and Linux builds are exported on a Mac.** They have not been run on real Windows or Linux computers by the author yet (their data was checked to be complete, but nobody has played them), so graphics-driver problems are possible there. Please report them with your graphics card and driver.
- The Windows `.exe` has Godot's default icon (a custom one needs an extra tool).

## Online play

- Games are joined by typing (or pasting) the host's IP address; there is no server list and no automatic discovery of games on the LAN.
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
- No gamepad support and English only (planned, see the roadmap in `docs/PLAN.md`).

## Game

- The sounds are simple, generated ones (a sound-design milestone is planned).
- Bots are not smart in team tactics (no callouts, no coordinated site takes), and how a round goes varies from game to game.
- Only three small maps, one bomb scenario, and no map voting. Community maps are welcome (CONTRIBUTING.md).
- There are no statistics or training modes yet beyond the Shooting Range.
