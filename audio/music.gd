class_name Music
extends RefCounted
## The music (M13, D-195): the main menu's looping track and the stingers that mark a round's
## start and end, a defused bomb and the match's end. Everything plays without position on the
## *Music* bus (its own volume in Settings). Made by `tools/generate_music.gd`, for Chiip.
##
## A plain class with static members, like [UiSounds]: two [AudioStreamPlayer]s it adds to the
## scene tree's root, so the track keeps playing from one menu scene to the next and while the
## game is paused. Off in headless runs (tests, tools), where sounds never finish.

const MENU_THEME := preload("res://assets/sounds/music/menu_theme.wav")
const ROUND_START := preload("res://assets/sounds/music/stinger_round_start.wav")
const ROUND_WON := preload("res://assets/sounds/music/stinger_round_won.wav")
const ROUND_LOST := preload("res://assets/sounds/music/stinger_round_lost.wav")
const BOMB_DEFUSED := preload("res://assets/sounds/music/stinger_bomb_defused.wav")
const MATCH_WON := preload("res://assets/sounds/music/stinger_match_won.wav")
const MATCH_LOST := preload("res://assets/sounds/music/stinger_match_lost.wav")
## How long the menu track takes to fade in and out, in seconds.
const FADE_TIME := 1.2
## The menu track plays this much under the stingers' level, in dB: it sits behind the menu.
const MENU_THEME_DB := -4.0

## Music plays only with a window (see [member UiSounds.enabled]).
static var enabled: bool = DisplayServer.get_name() != "headless"
static var _track: AudioStreamPlayer
static var _stinger: AudioStreamPlayer
static var _fade: Tween


## Starts the menu track (fading in), unless it is already playing.
static func play_menu() -> void:
	if not enabled:
		return
	if not _ensure_players():
		# The players join the tree at the end of the frame, the stinger's last; start once it's there.
		if is_instance_valid(_stinger) and not _stinger.ready.is_connected(play_menu):
			_stinger.ready.connect(play_menu, CONNECT_ONE_SHOT)
		return
	if _track.playing and _track.stream == MENU_THEME and _fade == null:
		return
	_stop_fade()
	if not (_track.playing and _track.stream == MENU_THEME):
		_track.stream = MENU_THEME
		_track.volume_db = -60.0
		_track.play()
	_fade = _track.create_tween()
	_fade.tween_property(_track, "volume_db", MENU_THEME_DB, FADE_TIME)
	_fade.finished.connect(func() -> void: _fade = null)


## Fades the menu track out and stops it (a game starts).
static func stop() -> void:
	if not is_instance_valid(_track) or not _track.playing:
		return
	_stop_fade()
	_fade = _track.create_tween()
	_fade.tween_property(_track, "volume_db", -60.0, FADE_TIME)
	_fade.tween_callback(_track.stop)
	_fade.finished.connect(func() -> void: _fade = null)


## True while the menu track plays (and isn't fading out).
static func is_playing_menu() -> bool:
	return is_instance_valid(_track) and _track.playing and _track.stream == MENU_THEME


## Plays [param stream] once, over whatever plays; a new stinger cuts the last one short.
static func play_stinger(stream: AudioStream) -> void:
	if not enabled or stream == null:
		return
	if not _ensure_players():
		if is_instance_valid(_stinger):
			_stinger.ready.connect(func() -> void: play_stinger(stream), CONNECT_ONE_SHOT)
		return
	_stinger.stream = stream
	_stinger.play()


## The stinger for a round that ended for the team you play or watch: a defused bomb has its own
## (everyone hears it), otherwise won or lost.
static func stinger_for_round(won: bool, reason: int) -> AudioStream:
	if reason == RoundManager.EndReason.BOMB_DEFUSED:
		return BOMB_DEFUSED
	return ROUND_WON if won else ROUND_LOST


## The stinger for the end of a match you won or lost.
static func stinger_for_match(won: bool) -> AudioStream:
	return MATCH_WON if won else MATCH_LOST


## Makes the two players on first use; true once they are in the tree (they join it at the end
## of the frame they were made in: a scene's `_ready()` can't add to the root at once).
static func _ensure_players() -> bool:
	if is_instance_valid(_track) and is_instance_valid(_stinger):
		return _track.is_inside_tree() and _stinger.is_inside_tree()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	_track = _make_player("MusicTrack")
	_stinger = _make_player("MusicStinger")
	tree.root.add_child.call_deferred(_track)
	tree.root.add_child.call_deferred(_stinger)
	return false


static func _make_player(player_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.bus = SoundMix.BUS_MUSIC
	# The menus work while the game is paused, and so does their music.
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	return player


static func _stop_fade() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = null
