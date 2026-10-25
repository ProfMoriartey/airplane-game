extends Node
## Plays music and one-off sound effects.
##
## Music crossfades between tracks. During missions it switches between a calm
## flying theme and a combat theme depending on whether enemies are close.
## Every button in the game clicks automatically.

const SFX := {
	click = preload("res://assets/audio/sfx/click.wav"),
	radio = preload("res://assets/audio/sfx/radio.wav"),
	bullet_hit = preload("res://assets/audio/sfx/bullet_hit.wav"),
	whizz = preload("res://assets/audio/sfx/whizz.wav"),
	explosion = preload("res://assets/audio/sfx/explosion.wav"),
	splash = preload("res://assets/audio/sfx/splash.wav"),
}
const MUSIC := {
	menu_theme = preload("res://assets/audio/music/menu_theme.wav"),
	flight_calm = preload("res://assets/audio/music/flight_calm.wav"),
	combat = preload("res://assets/audio/music/combat.wav"),
	victory = preload("res://assets/audio/music/victory.wav"),
	defeat = preload("res://assets/audio/music/defeat.wav"),
}
const STINGS := {
	promotion = preload("res://assets/audio/music/promotion.wav"),
	medal = preload("res://assets/audio/music/medal.wav"),
}
const FADE_TIME := 1.5
## How long after the last nearby enemy the music calms down again.
const COMBAT_COOLDOWN := 8.0
const UI_VOICES := 4

var _music: Array[AudioStreamPlayer] = []
var _active_music := 0
var _current_track := ""
var _flight_music := false
var _combat_timer := 0.0
var _ui_players: Array[AudioStreamPlayer] = []
var _next_ui := 0
var _sting: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for index in 2:
		var player := AudioStreamPlayer.new()
		player.bus = &"Music"
		add_child(player)
		_music.append(player)
	for index in UI_VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = &"UI"
		add_child(player)
		_ui_players.append(player)
	_sting = AudioStreamPlayer.new()
	_sting.bus = &"Music"
	add_child(_sting)
	get_tree().node_added.connect(_on_node_added)


func _exit_tree() -> void:
	# Stop everything so no playback is still held by the audio server at shutdown.
	for player in _music + _ui_players + [_sting]:
		player.stop()


func _process(delta: float) -> void:
	if not _flight_music:
		return
	_combat_timer -= delta
	var wanted := "combat" if _combat_timer > 0.0 else "flight_calm"
	if wanted != _current_track:
		play_music(wanted)


## Crossfades to a music track. Does nothing if it's already playing.
func play_music(track: String) -> void:
	if track == _current_track:
		return
	_current_track = track
	var old := _music[_active_music]
	_active_music = 1 - _active_music
	var new := _music[_active_music]
	new.stream = MUSIC[track]
	new.volume_db = -40.0
	new.play()
	var tween := create_tween().set_parallel()
	tween.tween_property(new, "volume_db", 0.0, FADE_TIME)
	tween.tween_property(old, "volume_db", -40.0, FADE_TIME)
	tween.chain().tween_callback(old.stop)


## Mission music: calm while cruising, combat music when enemies are near.
func start_flight_music() -> void:
	_flight_music = true
	_combat_timer = 0.0
	play_music("flight_calm")


func stop_flight_music() -> void:
	_flight_music = false


## Call while enemies are close; the combat music keeps going for a while after.
func report_combat() -> void:
	_combat_timer = COMBAT_COOLDOWN


## A short musical flourish over the current music, e.g. for a promotion.
func play_sting(sting: String) -> void:
	_sting.stream = STINGS[sting]
	_sting.play()


## A non-positional sound for menus and messages.
func play_ui(sound: String, volume_db := 0.0) -> void:
	var player := _ui_players[_next_ui]
	_next_ui = (_next_ui + 1) % UI_VOICES
	player.stream = SFX[sound]
	player.volume_db = volume_db
	player.play()


## A sound in the 3D world, at a position. It removes itself when finished.
func play_at(sound: String, at: Vector3, volume_db := 0.0, unit_size := 10.0) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = SFX[sound]
	player.bus = &"SFX"
	player.volume_db = volume_db
	player.unit_size = unit_size
	player.pitch_scale = randf_range(0.9, 1.1)
	player.finished.connect(player.queue_free)
	scene.add_child(player)
	player.global_position = at
	player.play()


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		node.pressed.connect(play_ui.bind("click"))
