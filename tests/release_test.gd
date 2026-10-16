extends Node
## Automated checks that Chiip is ready to be shared (M12, D-170 to D-179). Run without a window:
##
##     Godot --headless --path . --fixed-fps 128 --quit-after 60000 res://tests/release_test.tscn
##
## The licences: the licence files exist with the right words, the Licences screen reads every one of
## them and opens from the settings menu. Safe to publish: no personal path in a project text file,
## and the ignore file keeps the build and the editor's cache out of git. Quits with the number of
## failed checks as the exit code.

const SETTINGS_MENU_SCENE := preload("res://ui/settings_menu.tscn")
## File types that are plain text and checked for personal paths.
const TEXT_EXTENSIONS: Array[String] = [
	"md", "gd", "tscn", "tres", "cfg", "py", "sh", "txt", "json", "map", "godot", "csv", "html", "gdshader", "import", "css", "js", "yml",
]
## Folders that are not part of the project's sources.
const SKIPPED_FOLDERS: Array[String] = [".git", ".godot", "builds", ".claude", "__pycache__"]

var _failures: int = 0


func _ready() -> void:
	_test_licence_files()
	await _test_licences_screen()
	await _test_licences_from_settings()
	_test_export_presets()
	_test_contributing()
	_test_tailscale_addresses()
	await _test_tailscale_in_the_lobby()
	await _test_join_to_nobody()
	_test_website()
	_test_release_routine()
	_test_security_papers()
	_test_no_personal_paths()
	_test_gitignore()
	MenuState.reset()
	await get_tree().process_frame
	if _failures == 0:
		print("\nAll checks passed.")
	else:
		print("\n%d check(s) FAILED." % _failures)
	get_tree().quit(_failures)


# --- Licences ---


func _test_licence_files() -> void:
	var code := FileAccess.get_file_as_string("res://LICENSE")
	var assets := FileAccess.get_file_as_string("res://LICENSE-ASSETS")
	var notices := FileAccess.get_file_as_string("res://THIRD_PARTY_NOTICES.md")
	var font := FileAccess.get_file_as_string("res://assets/fonts/Silkscreen-OFL.txt")
	var addon := FileAccess.get_file_as_string("res://addons/func_godot/LICENSE")
	_check("LICENSE is the GNU GPL version 3 in full (the standard 35 KB text)",
			code.contains("GNU GENERAL PUBLIC LICENSE") and code.contains("Version 3, 29 June 2007") and code.length() > 30000,
			"%d characters" % code.length())
	_check("LICENSE-ASSETS names CC BY-NC-SA 4.0 and the folders it covers (assets, maps, docs/mapping) and what it leaves out: third-party files and the studio's name and logo (all rights reserved, D-174)",
			assets.contains("CC BY-NC-SA 4.0") and assets.contains("assets/") and assets.contains("maps/") and assets.contains("docs/mapping/")
					and assets.contains("legalcode") and assets.contains("Silkscreen") and assets.contains("LICENSE")
					and assets.contains("Divocakos") and assets.contains("ALL RIGHTS RESERVED") and assets.contains("studio_logo.png"),
			"%d characters" % assets.length())
	_check("THIRD_PARTY_NOTICES.md lists Godot (MIT, with its copyright line), FuncGodot and the Silkscreen font",
			notices.contains("Godot Engine") and notices.contains("Juan Linietsky") and notices.contains("FuncGodot")
					and notices.contains("Silkscreen") and notices.contains("MIT") and notices.contains("SIL Open Font License")
					and notices.contains("Divocakos") and notices.contains("all rights reserved"),
			"%d characters" % notices.length())
	_check("The font's and the addon's own licence files are in the project, as their licences ask",
			font.contains("SIL Open Font License") and addon.contains("MIT License"),
			"font %d, addon %d characters" % [font.length(), addon.length()])


func _test_licences_screen() -> void:
	var menu := (load("res://ui/licenses_menu.tscn") as PackedScene).instantiate() as LicensesMenu
	add_child(menu)
	await get_tree().process_frame
	var buttons := menu.get_document_buttons()
	_check("The Licences screen starts closed and lists a button for each of the %d documents" % LicensesMenu.DOCUMENTS.size(),
			not menu.is_open() and buttons.size() == LicensesMenu.DOCUMENTS.size() and not menu.visible,
			"%d buttons" % buttons.size())
	menu.open()
	await get_tree().process_frame
	_check("Opening it shows the overview (with the version and the source address), registers with MenuState and focuses Back",
			menu.is_open() and MenuState.is_top(menu) and menu.get_current() == &"overview"
					and not str(ProjectSettings.get_setting("application/config/version", "")).is_empty()
					and menu.get_text_label().text.contains(str(ProjectSettings.get_setting("application/config/version", "")))
					and menu.get_text_label().text.contains(LicensesMenu.SOURCE_URL) and menu.get_text_label().text.contains("© 2026 Divocakos")
					and get_viewport().gui_get_focus_owner() == menu.get_back_button(),
			"current %s" % menu.get_current())
	var all_read := true
	var missing := ""
	for document in LicensesMenu.DOCUMENTS:
		var id: StringName = document["id"]
		menu.show_document(id)
		var text := menu.get_text_label().text
		if text.length() < 200 or text.begins_with("This licence file is not in this build"):
			all_read = false
			missing += " %s(%d)" % [id, text.length()]
		if not menu.get_document_button(id).button_pressed:
			all_read = false
			missing += " %s-not-pressed" % id
	_check("Every document reads: the GPL, the asset licence, the notices, the font's and the addon's licences, the overview and Godot's own", all_read, "problems:%s" % missing)
	menu.show_document(&"godot")
	var godot_text := menu.get_text_label().text
	_check("The Godot entry comes from the engine itself: its licence, its components and the licence texts (Apache, BSD, zlib and the rest)",
			godot_text.contains("Godot Engine") and godot_text.contains("Permission is hereby granted") and godot_text.contains("Third-party components")
					and godot_text.contains("Apache-2.0") and godot_text.length() > 50000,
			"%d characters" % godot_text.length())
	menu.show_document(&"code")
	_check("The code entry is the GPL's text", menu.get_text_label().text.contains("GNU GENERAL PUBLIC LICENSE"), "")
	_check("A file missing from a build shows a line saying so instead of an empty page",
			LicensesMenu.read_file("res://nope/LICENSE").begins_with("This licence file is not in this build"), "")
	var closed_count: Array[int] = [0]
	menu.closed.connect(func() -> void: closed_count[0] += 1)
	menu.close()
	_check("Closing hides it, hands the mouse back (no menu left open) and emits closed once",
			not menu.is_open() and not MenuState.is_any_open() and closed_count[0] == 1, "closed %d times" % closed_count[0])
	remove_child(menu)
	menu.queue_free()
	MenuState.reset()


func _test_licences_from_settings() -> void:
	var settings := SETTINGS_MENU_SCENE.instantiate() as SettingsMenu
	add_child(settings)
	await get_tree().process_frame
	settings.open()
	var button := settings.get_licenses_button()
	var licences := settings.get_licenses_menu()
	_check("The settings menu's footer has a Licences button between the spacer and Back",
			button.text == "Licences" and button.theme_type_variation == &"DimButton" and button.get_index() == settings.get_back_button().get_index() - 1
					and not licences.is_open(),
			"'%s' at %d" % [button.text, button.get_index()])
	button.pressed.emit()
	await get_tree().process_frame
	_check("It opens the Licences screen over the settings, which stay open underneath; the screen is on top",
			licences.is_open() and settings.is_open() and MenuState.is_top(licences), "licences %s, settings %s" % [licences.is_open(), settings.is_open()])
	licences.close()
	await get_tree().process_frame
	_check("Closing the screen leaves the settings open with the focus back on the Licences button",
			not licences.is_open() and settings.is_open() and MenuState.is_top(settings)
					and get_viewport().gui_get_focus_owner() == button,
			"settings %s" % settings.is_open())
	settings.set_ui_scale(1.5)
	_check("Scaling the settings menu scales the Licences screen inside it too (UiTheme reaches the controls of every layer below)",
			(licences.get_node("Page") as Control).theme == UiTheme.scaled(1.5), "")
	settings.close()
	remove_child(settings)
	settings.queue_free()
	MenuState.reset()


# --- Export presets ---


func _test_export_presets() -> void:
	var config := ConfigFile.new()
	var loaded := config.load("res://export_presets.cfg")
	var names: Array[String] = []
	var by_name: Dictionary = {}
	for section in config.get_sections():
		if section.begins_with("preset.") and not section.ends_with(".options"):
			var preset_name: String = config.get_value(section, "name", "")
			names.append(preset_name)
			by_name[preset_name] = section
	_check("export_presets.cfg has the three presets (macOS, Windows, Linux), each for the right platform",
			loaded == OK and names == ["macOS", "Windows", "Linux"]
					and config.get_value(by_name["macOS"], "platform", "") == "macOS"
					and config.get_value(by_name["Windows"], "platform", "") == "Windows Desktop"
					and config.get_value(by_name["Linux"], "platform", "") == "Linux",
			"load %d, presets %s" % [loaded, names])
	var architectures: Dictionary = {"macOS": "universal", "Windows": "x86_64", "Linux": "x86_64"}
	var paths: Dictionary = {"macOS": "builds/macos/Chiip.app", "Windows": "builds/windows/Chiip.exe", "Linux": "builds/linux/Chiip.x86_64"}
	var arch_ok := true
	var path_ok := true
	var filters_ok := true
	var detail := ""
	var licence_files: Array[String] = ["LICENSE", "LICENSE-ASSETS", "THIRD_PARTY_NOTICES.md", "assets/fonts/Silkscreen-OFL.txt", "addons/func_godot/LICENSE"]
	for preset_name: String in architectures:
		var section: String = by_name.get(preset_name, "")
		if section.is_empty():
			arch_ok = false
			continue
		if config.get_value(section + ".options", "binary_format/architecture", "") != architectures[preset_name]:
			arch_ok = false
			detail += " %s-arch" % preset_name
		if config.get_value(section, "export_path", "") != paths[preset_name]:
			path_ok = false
			detail += " %s-path" % preset_name
		var include: String = config.get_value(section, "include_filter", "")
		var exclude: String = config.get_value(section, "exclude_filter", "")
		for file in licence_files:
			if not include.contains(file) or not FileAccess.file_exists("res://" + file):
				filters_ok = false
				detail += " %s-missing-%s" % [preset_name, file]
		if not exclude.contains("tests/*") or not exclude.contains("tools/*") or not exclude.contains("docs/*"):
			filters_ok = false
			detail += " %s-exclude" % preset_name
	_check("The architectures are universal (Mac) and x86_64 (Windows, Linux); the builds go to builds/<system>/Chiip.* (ignored by git)", arch_ok and path_ok, detail)
	_check("Every preset ships the licence files (the include filter lists LICENSE, LICENSE-ASSETS, THIRD_PARTY_NOTICES.md, the font's and the addon's licence, and they exist) and leaves tests/, tools/ and docs/ out", filters_ok, detail)
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	var mac := by_name.get("macOS", "") as String
	_check("The Mac app's version is the project's (%s) and nothing in any preset holds a signing identity or a password" % version,
			config.get_value(mac + ".options", "application/short_version", "") == version
					and config.get_value(mac + ".options", "application/version", "") == version
					and not _has_secrets(config),
			"short %s" % config.get_value(mac + ".options", "application/short_version", ""))
	_check("The Windows and Linux builds embed the data in the one file and carry desktop texture formats (S3TC / BPTC); the Mac app has no embedded pck",
			config.get_value(by_name["Windows"] + ".options", "binary_format/embed_pck", false) == true
					and config.get_value(by_name["Linux"] + ".options", "binary_format/embed_pck", false) == true
					and config.get_value(by_name["Windows"] + ".options", "texture_format/s3tc_bptc", false) == true
					and config.get_value(by_name["Linux"] + ".options", "texture_format/s3tc_bptc", false) == true,
			"")


## True when a preset holds a signing identity, a team id or a password with a value.
func _has_secrets(config: ConfigFile) -> bool:
	for section in config.get_sections():
		for key in config.get_section_keys(section):
			var lower := key.to_lower()
			if lower.contains("identity") or lower.contains("password") or lower.contains("apple_team_id") or lower.contains("api_key"):
				var value := str(config.get_value(section, key, ""))
				if not value.is_empty():
					return true
	return false


# --- A join that nobody answers ---


## Joining an address with no game behind it (a typo, Tailscale off) must end with a message after
## [constant NetSession.JOIN_TIMEOUT] seconds, not leave "Connecting..." up for the better part of a minute
## (ENet's own limit is 30 s).
func _test_join_to_nobody() -> void:
	MenuState.reset()
	GameLaunch.clear()
	var stored := Settings.new()
	stored.online_name = "Tester"
	var lobby := (load("res://ui/lobby_menu.tscn") as PackedScene).instantiate() as LobbyMenu
	lobby.set_settings(stored)
	add_child(lobby)
	await get_tree().process_frame
	lobby.open()
	lobby.get_address_field().text = "127.0.0.1"
	lobby.get_port_field().text = "28999"
	var result := lobby.join_game()
	var connecting_text := lobby.get_status_label().text
	var ticks := 0
	while lobby.get_join_button().disabled and ticks < 20 * 128:
		await get_tree().physics_frame
		ticks += 1
	var seconds := ticks / 128.0
	_check("Joining where no game runs says so after %.0f s (it took %.1f s of game time): the status names the usual causes and Join works again" % [NetSession.JOIN_TIMEOUT, seconds],
			result == OK and connecting_text.begins_with("Connecting to 127.0.0.1:28999") and seconds >= NetSession.JOIN_TIMEOUT - 0.1 and seconds < NetSession.JOIN_TIMEOUT + 2.0
					and lobby.get_status_label().text == NetSession.NO_HOST_TEXT and not lobby.get_join_button().disabled,
			"result %d, status '%s', %.1f s" % [result, lobby.get_status_label().text, seconds])
	lobby.close()
	remove_child(lobby)
	lobby.queue_free()
	MenuState.reset()


# --- Contributing and credits ---


func _test_contributing() -> void:
	var contributing := FileAccess.get_file_as_string("res://CONTRIBUTING.md")
	var readme := FileAccess.get_file_as_string("res://README.md")
	_check("CONTRIBUTING.md says how to submit a map (the map kit, MAPPING.md, MAPS.md, the maps test, the map lists), that maps are CC BY-NC-SA 4.0 and code GPL-3.0, and the README links to it",
			contributing.contains("docs/MAPPING.md") and contributing.contains("docs/MAPS.md") and contributing.contains("maps_test")
					and contributing.contains("ROTATION_MAPS") and contributing.contains("CC BY-NC-SA 4.0") and contributing.contains("GPL-3.0")
					and contributing.contains("pull request") and readme.contains("CONTRIBUTING.md"),
			"%d characters" % contributing.length())
	_check("The README credits \"Created by JK · Divocakos\" and keeps the studio's rights note; the Licences screen's overview credits it too",
			readme.contains("Created by JK · Divocakos") and readme.contains("all rights reserved")
					and LicensesMenu.overview_text().contains("Created by JK · Divocakos"),
			"")
	var notes := FileAccess.get_file_as_string("res://CHANGELOG.md")
	var checklist := FileAccess.get_file_as_string("res://docs/RELEASE_CHECKLIST.md")
	var known := FileAccess.get_file_as_string("res://docs/KNOWN_ISSUES.md")
	_check("The release papers exist: a changelog (the release notes) that credits \"Created by JK · Divocakos\" and name the three downloads, a checklist with every section, and the known issues",
			notes.contains("Created by JK · Divocakos") and notes.contains("windows-x86_64.zip") and notes.contains("macos-universal.zip") and notes.contains("linux-x86_64.zip")
					and checklist.contains("## 0. Gates") and checklist.contains("## 7. The builds") and checklist.contains("## 8. Before it goes public")
					and known.contains("## Builds") and known.contains("## Online play"),
			"notes %d, checklist %d, known issues %d characters" % [notes.length(), checklist.length(), known.length()])
	var maps_test := FileAccess.get_file_as_string("res://tests/maps_test.gd")
	var launch := FileAccess.get_file_as_string("res://systems/game_launch.gd")
	_check("The two lists CONTRIBUTING.md tells map authors to extend still exist (GameLaunch.ROTATION_MAPS and the maps test's MAPS)",
			launch.contains("const ROTATION_MAPS") and maps_test.contains("const MAPS"), "")


# --- The website ---


const SITE_PAGES: Array[String] = ["index.html", "download.html", "updates.html", "play.html", "maps.html", "about.html"]


## The website in site/ (M12, D-179): its pages and files, its links, its look (the game's tokens),
## the script's repository name and the workflow that publishes it.
func _test_website() -> void:
	var files_ok := true
	var missing := ""
	for path in SITE_PAGES + ["css/style.css", "js/site.js", "fonts/Silkscreen-Regular.ttf", "fonts/Silkscreen-Bold.ttf", "fonts/Silkscreen-OFL.txt",
			"img/menu.png", "img/bomb.png", "img/classes.png", "img/buy.png", "img/lobby.png", "img/divocakos.png", ".gdignore"]:
		if not FileAccess.file_exists("res://site/" + path):
			files_ok = false
			missing += " " + path
	_check("The site has its six pages, the stylesheet, the script, Silkscreen with its licence, five screenshots and the logo, and a .gdignore (Godot would import every picture otherwise)", files_ok, "missing:%s" % missing)

	var pages_ok := true
	var problems := ""
	var regex_link := RegEx.create_from_string("(?:href|src)=\"([^\"#]+)(?:#[^\"]*)?\"")
	var regex_image := RegEx.create_from_string("<img [^>]*>")
	for page in SITE_PAGES:
		var html := FileAccess.get_file_as_string("res://site/" + page)
		if not (html.contains("<title>") and html.contains("css/style.css") and html.contains("js/site.js") and html.contains("Created by JK · Divocakos")):
			pages_ok = false
			problems += " %s-basics" % page
		for other in SITE_PAGES.slice(1):
			if not html.contains('href="%s"' % other):
				pages_ok = false
				problems += " %s-nav-%s" % [page, other]
		for match in regex_link.search_all(html):
			var target := match.get_string(1)
			if target.begins_with("http://") or target.begins_with("https://") or target.begins_with("mailto:"):
				if target.contains("github.com/") and not target.contains("github.com/Jankozeluh/Chiip"):
					pages_ok = false
					problems += " %s-repo-%s" % [page, target]
				continue
			if not FileAccess.file_exists("res://site/" + target):
				pages_ok = false
				problems += " %s-broken-%s" % [page, target]
		for tag in regex_image.search_all(html):
			if not tag.get_string().contains("alt="):
				pages_ok = false
				problems += " %s-image-without-alt" % page
		# Nothing is loaded from elsewhere: no CDN scripts, styles, fonts or pictures.
		if html.contains('<script src="http') or html.contains('<link rel="stylesheet" href="http') or html.contains('<img src="http'):
			pages_ok = false
			problems += " %s-external" % page
		# The page's own security policy: scripts, styles, pictures and fonts only from the site itself, the
		# one outside connection is GitHub's API, and so no inline script, style or handler may exist.
		if not (html.contains("Content-Security-Policy") and html.contains("default-src 'none'") and html.contains("script-src 'self'") and html.contains("style-src 'self'")
				and html.contains("connect-src https://api.github.com") and html.contains("base-uri 'none'")):
			pages_ok = false
			problems += " %s-no-policy" % page
		if html.contains(" style=") or RegEx.create_from_string("<[^>]+ on[a-z]+=").search(html) != null or html.contains("javascript:") \
				or RegEx.create_from_string("<script(?![^>]* src=)").search(html) != null or html.contains("<iframe") or html.contains("<form") or html.contains("<object"):
			pages_ok = false
			problems += " %s-inline-code" % page
		if html.contains('target="_blank"') and not html.contains("noopener"):
			pages_ok = false
			problems += " %s-blank-without-noopener" % page
	_check("Every page carries the credit, the stylesheet and the script and links to all the others; every link and picture exists; every picture has alt text; the repository links all name the one repository; nothing loads from another site; every page has a content security policy and no inline script, style, handler, form or frame",
			pages_ok, "problems:%s" % problems)

	var css := FileAccess.get_file_as_string("res://site/css/style.css")
	var palette := FileAccess.get_file_as_string("res://tools/ui_palette.gd")
	var tokens: Dictionary = {"--void": "VOID", "--ink": "INK", "--panel": "PANEL", "--raised": "PANEL_RAISED", "--line": "LINE_COLOR", "--mute": "MUTE",
			"--text-dim": "TEXT_DIM", "--text": "TEXT", "--white": "TEXT_BRIGHT", "--accent": "ACCENT", "--accent-bright": "ACCENT_BRIGHT",
			"--friendly": "FRIENDLY", "--enemy": "ENEMY", "--alert": "ALERT"}
	var same := true
	var differing := ""
	for variable: String in tokens:
		var game := RegEx.create_from_string("const %s := Color\\(\"([0-9a-fA-F]{6})\"" % tokens[variable]).search(palette)
		var site := RegEx.create_from_string("%s:\\s*#([0-9a-fA-F]{6});" % variable).search(css)
		if game == null or site == null or game.get_string(1).to_lower() != site.get_string(1).to_lower():
			same = false
			differing += " %s" % variable
	_check("The site's colours are the game's own UI tokens (tools/ui_palette.gd): %d of them, same hex values, Silkscreen as the font" % tokens.size(),
			same and css.contains('font-family: "Silkscreen"') and css.contains("Silkscreen-Bold.ttf"), "differing:%s" % differing)

	var script := FileAccess.get_file_as_string("res://site/js/site.js")
	var readme := FileAccess.get_file_as_string("res://README.md")
	_check("The script reads the releases API of the one repository (the REPO line matches the README and the Licences screen), falls back to the plain latest-release link, picks the files by system, and its braces balance",
			script.contains('const REPO = "Jankozeluh/Chiip"') and readme.contains("github.com/Jankozeluh/Chiip") and LicensesMenu.SOURCE_URL.ends_with("Jankozeluh/Chiip")
					and script.contains("/releases/latest") and script.contains("/releases?per_page") and script.contains("windows") and script.contains("linux")
					and script.count("{") == script.count("}") and css.count("{") == css.count("}"),
			"")

	_check("The site's script is safe with what GitHub sends: no eval, no Function, no document.write, release notes become HTML in one place only (the markdown renderer, which escapes the text first and makes links only for http and https), the API answer is read inside try / catch, and nothing but the API is fetched",
			not script.contains("eval(") and not script.contains("new Function") and not script.contains("document.write") and not script.contains("insertAdjacentHTML")
					and not script.contains("outerHTML") and script.count("innerHTML") == 1 and script.contains("function escapeHtml") and script.contains("(https?:\\/\\/")
					and script.count("fetch(") == 1 and script.contains("API + path") and script.contains("try {") and script.contains("catch (error)"),
			"innerHTML used %d times, fetch %d times" % [script.count("innerHTML"), script.count("fetch(")])

	var workflow := FileAccess.get_file_as_string("res://.github/workflows/pages.yml")
	var pinned := {"actions/checkout": "11bd71901bbe5b1630ceea73d27597364c9af683", "actions/upload-pages-artifact": "56afc609e74202658d3ffba0e8f6dda462b719fa",
			"actions/deploy-pages": "d6db90164ac5ed86f2b6aed7e0febac5b3c0c03e"}
	var uses_ok := true
	var uses_count := 0
	var sha_line := RegEx.create_from_string("^uses: (actions/[a-z-]+)@([0-9a-f]{40}) # v[0-9]+\\.[0-9]+\\.[0-9]+$")
	for line in workflow.split("\n"):
		var trimmed := line.strip_edges().trim_prefix("- ")
		if trimmed.begins_with("uses:"):
			uses_count += 1
			var found := sha_line.search(trimmed)
			if found == null or pinned.get(found.get_string(1), "") != found.get_string(2):
				uses_ok = false
	_check("The Pages workflow publishes site/ on every push to main with only GitHub's own actions (checkout, upload-pages-artifact, deploy-pages), each pinned to the full commit SHA of its release with the version in a comment",
			uses_ok and uses_count == 3 and workflow.contains("branches: [main]") and workflow.contains("path: site"),
			"%d actions, %d characters" % [uses_count, workflow.length()])
	var dependabot := FileAccess.get_file_as_string("res://.github/dependabot.yml")
	# Without its comment lines (which say what the workflow doesn't do).
	var code_lines: Array[String] = []
	for line in workflow.split("\n"):
		if not line.strip_edges().begins_with("#"):
			code_lines.append(line)
	workflow = "\n".join(code_lines)
	_check("The workflow asks for the least it needs (read the repository, write Pages, the deploy token), uses no secrets, never runs for pull requests from forks (no pull_request_target, no pull_request), and Dependabot keeps the pins up to date",
			workflow.contains("contents: read") and workflow.contains("pages: write") and workflow.contains("id-token: write") and not workflow.contains("write-all")
					and not workflow.contains("secrets.") and not workflow.contains("pull_request") and not workflow.contains("contents: write")
					and dependabot.contains('package-ecosystem: "github-actions"'),
			"")


## The update routine: the changelog holds a section for the project's version that tools/release_notes.sh can extract,
## and docs/RELEASING.md names the steps.
func _test_release_routine() -> void:
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	var changelog := FileAccess.get_file_as_string("res://CHANGELOG.md")
	var releasing := FileAccess.get_file_as_string("res://docs/RELEASING.md")
	var output: Array = []
	var exit_code := OS.execute("bash", [ProjectSettings.globalize_path("res://tools/release_notes.sh"), version], output)
	var notes := "" if output.is_empty() else str(output[0])
	var missing: Array = []
	var missing_exit := OS.execute("bash", [ProjectSettings.globalize_path("res://tools/release_notes.sh"), "99.99.99"], missing)
	_check("CHANGELOG.md has a section \"## [%s]\" for the project's version and tools/release_notes.sh prints its text (no heading) and refuses a version it doesn't have" % version,
			changelog.contains("## [%s] - " % version) and exit_code == 0 and notes.length() > 500 and not notes.contains("## [") and notes.contains("Created by JK · Divocakos")
					and missing_exit == 1,
			"exit %d, %d characters, missing version exit %d" % [exit_code, notes.length(), missing_exit])
	_check("docs/RELEASING.md gives the routine: bump version and changelog, run the suite, export, zip, gh release create; the site follows by itself",
			releasing.contains("project.godot") and releasing.contains("CHANGELOG.md") and releasing.contains("tools/run_tests.sh") and releasing.contains("--export-release")
					and releasing.contains("tools/package_release.sh") and releasing.contains("gh release create") and releasing.contains("site"),
			"%d characters" % releasing.length())


# --- Security ---


## The security papers and tools (M12, D-180): SECURITY.md, the checksums of a release, the script that hardens the
## repository's settings, and the scan of the whole history for keys, tokens, secrets and e-mail addresses (run for
## real on this checkout's history; skipped without git or Python).
func _test_security_papers() -> void:
	var security := FileAccess.get_file_as_string("res://SECURITY.md")
	var package := FileAccess.get_file_as_string("res://tools/package_release.sh")
	var readme := FileAccess.get_file_as_string("res://README.md")
	var releasing := FileAccess.get_file_as_string("res://docs/RELEASING.md")
	var checklist := FileAccess.get_file_as_string("res://docs/RELEASE_CHECKLIST.md")
	_check("SECURITY.md says how to report a problem privately and what the game does; a release carries SHA256SUMS.txt (made by the packaging script, checked in the README, published by the release routine); the checklist has its security review",
			security.contains("Report a vulnerability") and security.contains("netsec_test") and package.contains("SHA256SUMS.txt") and package.contains("shasum -a 256")
					and readme.contains("SHA256SUMS.txt") and readme.contains("Get-FileHash") and releasing.contains("SHA256SUMS.txt") and releasing.contains("tools/harden_repo.sh")
					and checklist.contains("## 9. Security review"),
			"")
	var harden := FileAccess.get_file_as_string("res://tools/harden_repo.sh")
	var output: Array = []
	var exit_code := OS.execute("bash", [ProjectSettings.globalize_path("res://tools/harden_repo.sh"), "Owner/Repo", "--protect-main", "--dry-run"], output)
	var dry := "" if output.is_empty() else str(output[0])
	_check("The script that hardens the repository's settings sets read-only workflow permissions, approval for first-time contributors, Dependabot, secret scanning with push protection, private vulnerability reporting and (on request) pull-request-only main; its dry run prints those commands and changes nothing",
			harden.contains("default_workflow_permissions=read") and harden.contains("fork-pr-contributor-approval") and harden.contains("vulnerability-alerts")
					and harden.contains("secret_scanning_push_protection") and harden.contains("private-vulnerability-reporting") and harden.contains("branches/main/protection")
					and exit_code == 0 and dry.contains("would: workflows: read-only") and dry.contains("would: protect main") and not dry.contains("done:"),
			"exit %d, %d characters" % [exit_code, dry.length()])
	var has_git := FileAccess.file_exists("res://.git") or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://.git"))
	if has_git:
		var scan_output: Array = []
		var scan_exit := OS.execute("python3", ["-I", ProjectSettings.globalize_path("res://tools/scan_history.py"), "HEAD"], scan_output)
		var text := "" if scan_output.is_empty() else str(scan_output[0])
		if scan_exit == -1:
			print("SKIP  the history scan: python3 could not be started")
		else:
			_check("The whole history of this branch has no key, token, secret assignment, e-mail address or sensitive file name (tools/scan_history.py, every line ever added)",
					scan_exit == 0 and text.contains("0 kind(s) of finding need a look."), "exit %d: %s" % [scan_exit, text.substr(maxi(text.length() - 90, 0)).replace("\n", " ")])


# --- Tailscale ---


func _test_tailscale_addresses() -> void:
	var tailscale_ok := true
	for address in ["100.64.0.0", "100.100.100.100", "100.127.255.255", "100.101.102.103"]:
		tailscale_ok = tailscale_ok and LobbyMenu.is_tailscale_address(address)
	var others_ok := true
	for address in ["100.63.255.255", "100.128.0.1", "99.64.0.1", "10.0.0.1", "192.168.1.20", "127.0.0.1", "100.64.1", "100.64.1.256", "100.64.x.1", "fd7a:115c:a1e0::1", "", "100.64.0.1.2"]:
		others_ok = others_ok and not LobbyMenu.is_tailscale_address(address)
	_check("100.64.0.0/10 is Tailscale's range: 100.64.0.0 to 100.127.255.255 count, the neighbours (100.63.x, 100.128.x), private ranges, loopback and bad strings do not",
			tailscale_ok and others_ok, "in range %s, others %s" % [tailscale_ok, others_ok])
	var found := PackedStringArray(["127.0.0.1", "192.168.1.20", "100.101.102.103", "fd7a:115c:a1e0::1", "169.254.1.1", "100.101.102.103", "10.0.0.5", "0.0.0.0"])
	_check("A computer's address list splits into its Tailscale addresses (once each) and the same-network ones (no loopback, link-local, IPv6 or Tailscale)",
			LobbyMenu.tailscale_addresses(found) == ["100.101.102.103"] and LobbyMenu.local_addresses(found) == ["192.168.1.20", "10.0.0.5"]
					and LobbyMenu.tailscale_addresses(PackedStringArray(["192.168.1.20"])).is_empty(),
			"tailscale %s, local %s" % [LobbyMenu.tailscale_addresses(found), LobbyMenu.local_addresses(found)])
	var with_port := LobbyMenu.split_address("100.101.102.103:26000")
	var named := LobbyMenu.split_address("  jan-mac.tail1234.ts.net:27000 ")
	var plain := LobbyMenu.split_address("100.101.102.103")
	var ipv6 := LobbyMenu.split_address("fd7a:115c:a1e0::1")
	var bad_port := LobbyMenu.split_address("host:99999")
	var zero_port := LobbyMenu.split_address("host:0")
	var no_host := LobbyMenu.split_address(":26000")
	_check("Pasting \"address:port\" (what Copy puts on the clipboard) into Join by IP splits into the address and the port; a bare address, a host name, an IPv6 address or a bad port are left whole",
			with_port == {"address": "100.101.102.103", "port": 26000} and named == {"address": "jan-mac.tail1234.ts.net", "port": 27000}
					and plain == {"address": "100.101.102.103"} and ipv6 == {"address": "fd7a:115c:a1e0::1"}
					and bad_port == {"address": "host:99999"} and zero_port == {"address": "host:0"} and no_host == {"address": ":26000"},
			"%s %s %s %s %s" % [with_port, named, plain, ipv6, bad_port])


func _test_tailscale_in_the_lobby() -> void:
	MenuState.reset()
	GameLaunch.clear()
	var stored := Settings.new()
	stored.online_name = "Tester"
	stored.online_port = 28944
	var lobby := (load("res://ui/lobby_menu.tscn") as PackedScene).instantiate() as LobbyMenu
	lobby.set_settings(stored)
	add_child(lobby)
	await get_tree().process_frame
	lobby.set_ui_scale(1.0)
	lobby.address_source = func() -> PackedStringArray: return PackedStringArray(["127.0.0.1", "192.168.1.20", "100.101.102.103"])
	lobby.open()
	var result := lobby.host_game()
	await get_tree().process_frame
	_check("A host with a Tailscale address (and a LAN one) sees Friends join at: the Tailscale address with the port and a Copy button first, then \"Same network\" and the LAN address; the header names the LAN address",
			result == OK and lobby.get_friends_box().visible and lobby.get_tailscale_box().visible
					and lobby.get_tailscale_text() == "100.101.102.103:28944" and lobby.get_copy_button().text == "Copy"
					and lobby.get_lan_label().visible and lobby.get_address_texts() == ["192.168.1.20:28944"]
					and lobby.get_info_label().text == "Hosted by you · 192.168.1.20:28944"
					and lobby.get_tailscale_box().get_index() < lobby.get_lan_label().get_index(),
			"result %d, tailscale '%s', lan %s, header '%s'" % [result, lobby.get_tailscale_text(), lobby.get_address_texts(), lobby.get_info_label().text])
	lobby.get_copy_button().pressed.emit()
	await get_tree().process_frame
	var clipboard_works := DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD)
	_check("Copy puts \"100.101.102.103:28944\" on the clipboard (where the display server has one) and says Copied for a moment, then Copy again",
			lobby.get_copy_button().text == "Copied" and (not clipboard_works or DisplayServer.clipboard_get() == "100.101.102.103:28944"),
			"button '%s', clipboard %s" % [lobby.get_copy_button().text, DisplayServer.clipboard_get() if clipboard_works else "n/a in this run"])
	await get_tree().create_timer(LobbyMenu.COPIED_MILLISECONDS / 1000.0 + 0.4).timeout
	_check("The button goes back to Copy after the moment", lobby.get_copy_button().text == "Copy", "'%s'" % lobby.get_copy_button().text)
	lobby.close()
	await _wait_for_session_close(lobby)
	# Only a Tailscale address: it is the whole list and names the host in the header.
	lobby.address_source = func() -> PackedStringArray: return PackedStringArray(["127.0.0.1", "100.64.7.8"])
	lobby.open()
	result = lobby.host_game()
	await get_tree().process_frame
	_check("A host with only a Tailscale address still sees Friends join at (no same-network lines or caption) and the header names that address",
			result == OK and lobby.get_friends_box().visible and lobby.get_tailscale_text() == "100.64.7.8:28944" and not lobby.get_lan_label().visible
					and lobby.get_address_texts().is_empty() and lobby.get_info_label().text == "Hosted by you · 100.64.7.8:28944",
			"result %d, tailscale '%s', header '%s'" % [result, lobby.get_tailscale_text(), lobby.get_info_label().text])
	lobby.close()
	await _wait_for_session_close(lobby)
	# No Tailscale: the old look, the same-network lines alone.
	lobby.address_source = func() -> PackedStringArray: return PackedStringArray(["127.0.0.1", "192.168.1.20"])
	lobby.open()
	result = lobby.host_game()
	await get_tree().process_frame
	_check("A host without Tailscale sees no Tailscale group and no caption: just the same-network address, as before",
			result == OK and lobby.get_friends_box().visible and not lobby.get_tailscale_box().visible and lobby.get_tailscale_text().is_empty()
					and not lobby.get_lan_label().visible and lobby.get_address_texts() == ["192.168.1.20:28944"],
			"result %d, lan %s" % [result, lobby.get_address_texts()])
	lobby.close()
	await _wait_for_session_close(lobby)
	# Joining: "address:port" in the address field fills both fields.
	lobby.open()
	lobby.get_address_field().text = "100.101.102.103:27001"
	lobby.get_address_field().text_changed.emit(lobby.get_address_field().text)
	var join_result := lobby.join_game()
	await get_tree().process_frame
	_check("Joining with a pasted \"address:port\" uses that port and shows the address and the port in their own fields (the connection attempt starts, then Back cancels it)",
			join_result == OK and stored.online_address == "100.101.102.103" and stored.online_port == 27001
					and lobby.get_address_field().text == "100.101.102.103" and lobby.get_port_field().text == "27001",
			"result %d, address '%s' port %d" % [join_result, stored.online_address, stored.online_port])
	lobby.close()
	await _wait_for_session_close(lobby)
	remove_child(lobby)
	lobby.queue_free()
	MenuState.reset()


## Waits (a few seconds at most) until the lobby has let go of the session it closed: a host gives its
## friends a moment to hear the end, and hosting again before that is refused.
func _wait_for_session_close(lobby: LobbyMenu) -> void:
	for step in 240:
		if not lobby.is_closing_session():
			return
		await get_tree().process_frame


# --- Safe to publish ---


func _test_no_personal_paths() -> void:
	# Built from parts so this file doesn't contain the text it looks for.
	var forbidden: Array[String] = ["/Us" + "ers/", "C:\\Us" + "ers\\", "kozel" + "uhj", "claude.ai/" + "artifact", "Kože" + "luh", "Koze" + "luh"]
	var files := _text_files("res://")
	var hits: Array[String] = []
	for path in files:
		var text := FileAccess.get_file_as_string(path)
		for needle in forbidden:
			if text.contains(needle):
				hits.append("%s (%s)" % [path, needle])
				break
	_check("No project text file names a personal path, a user name or a link to a private page (%d files read)" % files.size(), hits.is_empty() and files.size() > 100,
			"%d hits, first: %s" % [hits.size(), hits.slice(0, 5)])


func _test_gitignore() -> void:
	var ignore := FileAccess.get_file_as_string("res://.gitignore")
	_check("The ignore file keeps the editor's cache (.godot/) and the exported builds (/builds/) out of git",
			ignore.contains(".godot/") and ignore.contains("/builds/"), "%d characters" % ignore.length())
	_check("It also keeps export passwords and signing keys out (export_credentials.cfg, .p12, .keystore) and the per-machine Claude files",
			ignore.contains("export_credentials.cfg") and ignore.contains("*.p12") and ignore.contains("*.keystore") and ignore.contains(".claude/worktrees/"),
			"")


## Every plain-text project file under [param folder] (not the editor's cache, git, builds).
func _text_files(folder: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(folder)
	if dir == null:
		return found
	for entry in dir.get_directories():
		if not SKIPPED_FOLDERS.has(entry):
			found.append_array(_text_files(folder.path_join(entry)))
	for file in dir.get_files():
		if TEXT_EXTENSIONS.has(file.get_extension()):
			found.append(folder.path_join(file))
	return found


func _check(check_name: String, passed: bool, detail: String) -> void:
	print("%s  %s: %s" % ["PASS" if passed else "FAIL", check_name, detail])
	if not passed:
		_failures += 1
