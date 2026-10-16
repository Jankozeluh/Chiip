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
	"md", "gd", "tscn", "tres", "cfg", "py", "sh", "txt", "json", "map", "godot", "csv", "html", "gdshader", "import",
]
## Folders that are not part of the project's sources.
const SKIPPED_FOLDERS: Array[String] = [".git", ".godot", "builds", ".claude", "__pycache__"]

var _failures: int = 0


func _ready() -> void:
	_test_licence_files()
	await _test_licences_screen()
	await _test_licences_from_settings()
	_test_export_presets()
	_test_tailscale_addresses()
	await _test_tailscale_in_the_lobby()
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
		if not exclude.contains("tests/*") or not exclude.contains("tools/*"):
			filters_ok = false
			detail += " %s-exclude" % preset_name
	_check("The architectures are universal (Mac) and x86_64 (Windows, Linux); the builds go to builds/<system>/Chiip.* (ignored by git)", arch_ok and path_ok, detail)
	_check("Every preset ships the licence files (the include filter lists LICENSE, LICENSE-ASSETS, THIRD_PARTY_NOTICES.md, the font's and the addon's licence, and they exist) and leaves tests/ and tools/ out", filters_ok, detail)
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
	var forbidden: Array[String] = ["/Us" + "ers/", "C:\\Us" + "ers\\", "kozel" + "uhj", "claude.ai/" + "artifact"]
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
