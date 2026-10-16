# Chiip's website

Plain HTML, CSS and one small script: no build tools, no frameworks, no downloads. `.github/workflows/pages.yml` publishes this folder to GitHub Pages on every push to main (the folder has a `.gdignore`, so Godot ignores it).

- **Preview it:** `python3 -m http.server --directory site 8000`, then open <http://localhost:8000>. (Opening the files directly also works, except that the browser may refuse the font.)
- **Pages:** `index.html` (what Chiip is, screens), `download.html`, `updates.html`, `play.html` (the Tailscale guide), `maps.html` (community maps), `about.html` (credits and licences). Each is a complete page with the same header and footer; to change the menu, change it in all six.
- **The script** (`js/site.js`) reads GitHub's public releases API: it points the download buttons at the latest release's files (found by `windows`, `mac` or `linux` in the file name), highlights the visitor's system, and lists every release's notes (the sections of `CHANGELOG.md`) on the Updates page. Without JavaScript, or when the API can't be reached, the buttons keep the plain link to the latest release that is written in the HTML. The repository's name is the line `const REPO` at the top of the script.
- **The look** is the game's: Silkscreen for headings and labels (`fonts/`, with its OFL licence), the UI theme's colours (`css/style.css` has the same hex values as `tools/ui_palette.gd`; `release_test` checks), square boxes, 2 px borders, hard shadows.
- **Licences of what is in here:** the HTML, CSS and script are GPL-3.0 like the code; the screenshots (`img/` except the logo) are CC BY-NC-SA 4.0 like the game's art; the font is SIL OFL 1.1; the Divocakos logo (`img/divocakos.png`) and name are all rights reserved (`LICENSE-ASSETS`).
- **New screenshots:** `tools/ui_screenshots.gd` makes them without touching the mouse (see `docs/DEVELOPING.md`); copy the ones you want to `img/`.
