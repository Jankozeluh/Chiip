# Security

Chiip is a hobby game, but it opens a network port when you host, so security reports are welcome.

## Reporting a problem

Please **do not open a public issue** for something that could hurt players (a crash or a hang that a friend's computer can cause on the host, a way to read or write files, a flaw in the website or the release files). Use GitHub's **private vulnerability reporting**: on the repository's page, *Security → Report a vulnerability*. Say what you found, how to reproduce it and which version (see **Settings → Licences**, or the bottom left of the main menu).

You'll get an answer within a few days. Fixes ship in the next release (or a quick patch release), and the reporter is credited in the changelog unless they prefer not to be.

## What the game does about it

- The host does not trust the computers that join it: it limits and checks what they send, and removes a computer that floods it or never introduces itself. Nothing received is ever turned into an object or run as code. The tests are `tests/netsec_test.gd`.
- Online play is meant for a private network ([Tailscale](https://tailscale.com)); the game never opens ports on a router by itself.
- The downloads come with SHA-256 checksums in each release. The builds are not code-signed (see the README).
- The full list of checks before a release is [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md), section 9.

## Supported versions

Only the latest release.
