# Chiip: known issues

> What doesn't work yet or hasn't been checked, for the first public playtest (v0.1.0). Reported bugs go to the GitHub issues. This list is finished by the pre-release QA pass (M12); until then it holds what is known from building the game.
>
> Last updated: 2026-10-16

## Builds

- **The builds are not signed.** Windows SmartScreen and macOS Gatekeeper warn the first time; the README says how to get past it.
- **The Windows and Linux builds are exported on a Mac.** They have not been run on real Windows or Linux computers by the author yet, so graphics-driver problems are possible there. Please report them with your graphics card and driver.

## Online play

- Games are joined by typing (or pasting) the host's IP address; there is no server list and no automatic discovery of games on the LAN.
- The host plays too: there is no dedicated server, so the match ends for everyone when the host quits, and the host's connection decides how good it is for the others.
- Everyone must run the same version of the game.
- Internet play is meant to go through Tailscale (see the README). Other ways to reach the host (a forwarded port on the router) work but aren't supported.

## Game

- Bots are not smart in team tactics (no callouts, no coordinated site takes), and how a round goes varies from game to game.
- Only three small maps, one bomb scenario, and no map voting.
- Weapon and class names are provisional.
