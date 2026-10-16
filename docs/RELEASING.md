# Releasing Chiip

> The routine for every release after the first (M12, D-179): five steps from the version number to a published release, and the website follows by itself. Builds are made **only when the owner says so** (CLAUDE.md); the owner approves the push and the release.
>
> Last updated: 2026-10-16

How the pieces fit: a release is a **tag** on main plus a **GitHub Release** holding the three zips and the notes. The notes are the version's section of [CHANGELOG.md](../CHANGELOG.md). The website ([site/](../site/)) reads the releases through GitHub's API: its Download buttons always point to the latest release's files and its Updates page lists every release's notes, so **a new release needs no edit to the site**. The site itself is republished by `.github/workflows/pages.yml` on every push to main.

You need once per computer: the Godot 4.7.2 export templates ([DEVELOPING.md](DEVELOPING.md), "Exporting the game"), and the GitHub command line (`brew install gh`, then `gh auth login`).

## The five steps

**1. Bump the version.** Write what changed.
- `config/version` in `project.godot` (for example `0.2.0`) and, in `export_presets.cfg`, the macOS preset's `application/short_version` and `application/version` (`release_test` fails if they differ).
- In [CHANGELOG.md](../CHANGELOG.md) add a section **above** the previous one, with the heading in exactly this form: `## [0.2.0] - 2026-11-20`. Its text is the release notes, so write it for players: what is new, what is fixed, anything they must know (a new minimum version, a changed setting). Keep the `###` sub-headings and a link to [KNOWN_ISSUES.md](KNOWN_ISSUES.md).
- Update [KNOWN_ISSUES.md](KNOWN_ISSUES.md), and `NetProtocol.VERSION` (`net/net_protocol.gd`) if the network packets changed (players on the old version are then refused with a clear message).
- Check the notes: `bash tools/release_notes.sh 0.2.0` prints them (exit code 1 means the section is missing or empty).
- Commit: `Release 0.2.0`.

**2. Run the checks.**
- `bash tools/run_tests.sh` (all suites must pass; use `TMPDIR=<folder>` if another game runs on the computer) and `bash tools/lan_check.sh`.
- Walk through [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md): sections 1 to 6 for what changed, 7 for the builds.

**3. Export the three builds** (only when asked):

```bash
mkdir -p builds/windows builds/linux builds/macos && touch builds/.gdignore
"$GODOT" --headless --path "$PROJECT" --export-release "Windows" builds/windows/Chiip.exe
"$GODOT" --headless --path "$PROJECT" --export-release "Linux" builds/linux/Chiip.x86_64
"$GODOT" --headless --path "$PROJECT" --export-release "macOS" builds/macos/Chiip.app
```

Smoke-test the Mac build: `builds/macos/Chiip.app/Contents/MacOS/Chiip --headless --quit-after 900 -- --map res://maps/depot.tscn`. Start it once with a window and look at **Settings → Licences** (every document must show its text).

**4. Zip them:** `bash tools/package_release.sh` writes `builds/release/Chiip-<version>-windows-x86_64.zip`, `…-linux-x86_64.zip` and `…-macos-universal.zip`, each with the licences next to the game. (The site finds the right file by the words `windows`, `mac` and `linux` in the file names: keep them.)

**5. Tag, push, publish.**

```bash
git tag -a v0.2.0 -m "Chiip 0.2.0"
git push origin main --tags
bash tools/release_notes.sh 0.2.0 > builds/release/notes.md
gh release create v0.2.0 builds/release/Chiip-0.2.0-*.zip --title "Chiip v0.2.0" --notes-file builds/release/notes.md
```

Add `--prerelease` for a test version (the site's Download buttons follow the latest *full* release; the Updates page lists both). Then check, from a browser that isn't signed in to GitHub:
- the release page shows the three files and the notes;
- the website's **Download** page offers the new version (it can take up to ten minutes to show for someone who opened the site earlier: the page remembers GitHub's answer that long) and its **Updates** page lists the notes;
- a download starts and the unzipped game runs.

## If something is wrong

- **A mistake in the notes:** `gh release edit v0.2.0 --notes-file builds/release/notes.md` after fixing CHANGELOG.md.
- **A bad file:** `gh release upload v0.2.0 <file> --clobber`.
- **A bad release:** `gh release delete v0.2.0 --cleanup-tag` and start again; players who downloaded it keep what they have, so say what happened in the next release's notes.
- **A hotfix:** the same five steps with a patch version (`0.2.1`).

## One-time setup (the first release only)

1. Create the public repository and push main (D-171, D-176).
2. Turn on Pages with the Actions source: `gh api -X POST repos/<owner>/<repo>/pages -f build_type=workflow`, or in the repository's *Settings → Pages → Build and deployment → Source: GitHub Actions*. The workflow then publishes `site/` on every push to main; the address is `https://<owner>.github.io/<repo>/`.
3. If the repository's name or owner is not `Jankozeluh/Chiip`, change it in `site/js/site.js` (the line `const REPO`), in the links of `site/*.html` (search for `github.com/`), in `ui/licenses_menu.gd` (`SOURCE_URL`) and in the README.
4. Fill in the repository's description and topics, and put the website's address in its *About* box.
