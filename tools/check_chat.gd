extends SceneTree
## Chat in an exported build (v0.2.0 release check): a host and a friend talk over real ENet on loopback, with the
## game data of an exported build (tools/check_release.sh runs it with this Mac's Godot and the build's pack:
## Godot --headless --main-pack <Chiip.pck> --script tools/check_chat.gd, from a folder that is not the project).
## An exported game itself ignores --script. The friend's line carries BBCode and a direction mark: both must
## arrive as plain text. Prints "Chiip chat check: PASS ..." or FAIL ..., and quits with 0 or 1.
const PORT := 28801  # not the game's own, not lan_check's

func _wait(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await physics_frame
	return cond.call()

func _init() -> void:
	await physics_frame
	var host_side := Node.new()
	host_side.name = "HostSide"
	root.add_child(host_side)
	set_multiplayer(SceneMultiplayer.new(), host_side.get_path())
	var friend_side := Node.new()
	friend_side.name = "FriendSide"
	root.add_child(friend_side)
	set_multiplayer(SceneMultiplayer.new(), friend_side.get_path())
	var host := NetSession.open(self, host_side)
	var friend := NetSession.open(self, friend_side)
	if host.host_game("Host", PORT) != OK:
		print("Chiip chat check: FAIL (could not host)")
		quit(1)
		return
	friend.join_game("127.0.0.1", "Ana", PORT)
	var joined := await _wait(friend.is_active, 1500)
	var host_chat := NetChat.of(host)
	var friend_chat := NetChat.of(friend)
	friend_chat.send("hello from Ana [b]bold[/b]" + String.chr(0x202E) + " end")
	host_chat.send("hi Ana")
	var heard := await _wait(func() -> bool: return host_chat.lines.size() >= 2 and friend_chat.lines.size() >= 2, 1500)
	var texts: Array = []
	for line in host_chat.lines:
		texts.append("%s: %s" % [line["name"], line["text"]])
	var plain := true
	for line in friend_chat.lines:
		for character in String(line["text"]):
			if character.unicode_at(0) == 0x202E:
				plain = false
	var ok: bool = joined and heard and plain and texts.size() == 2 and texts.has("Host: hi Ana") and texts.any(func(t: String) -> bool: return t.begins_with("Ana: hello from Ana [b]bold[/b]"))
	print("Chiip chat check: %s (joined %s, both heard both lines %s, direction mark gone %s, host saw %s)" % ["PASS" if ok else "FAIL", joined, heard, plain, texts])
	host.close()
	friend.close()
	await create_timer(0.5).timeout
	quit(0 if ok else 1)
