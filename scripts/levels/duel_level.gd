class_name DuelLevel
extends Level
## Ace Duels: one on one against a named enemy ace.

const DEBRIEF_SCENE := preload("res://scenes/ui/debrief.tscn")
const ENEMY_SCENE := preload("res://scenes/aircraft/enemy_plane.tscn")
const DUELS_SCREEN := "res://scenes/ui/duels_screen.tscn"
const START_DISTANCE := 1600.0
const DEBRIEF_DELAY := 3.0

## Which ace (index into Aces.ACES) the next duel is against.
static var ace_index := 0

var _ace: Aircraft
var _elapsed := 0.0
var _damage_taken := 0.0
var _finished := false


func _enter_tree() -> void:
	var ace: Dictionary = Aces.ACES[ace_index]
	TheaterPresets.apply(ace.theater, $Terrain)
	var weather := $Weather as Weather
	weather.time_of_day = ace.time_of_day
	weather.cloud_altitude = TheaterPresets.THEATERS[ace.theater].cloud_altitude
	$PlayerPlane.position.y = TheaterPresets.THEATERS[ace.theater].start_height


func _ready() -> void:
	super()
	var ace: Dictionary = Aces.ACES[ace_index]
	var aircraft := Profile.selected_aircraft()
	player.set_stats(aircraft, Profile.livery_of(aircraft.id))

	# The ace appears ahead, flying straight at the player: a classic head-on start.
	_ace = ENEMY_SCENE.instantiate() as Aircraft
	_ace.stats = ace.stats
	_ace.pilot_name = ace.name
	var ai := _ace.get_node("AI") as AircraftAI
	ai.skill = AircraftAI.Skill.ACE
	ai.patrol_center = player.global_position
	var start := player.global_position - player.global_basis.z * START_DISTANCE
	_ace.transform = Transform3D(Basis.IDENTITY, start).looking_at(player.global_position, Vector3.UP)
	_ace.destroyed.connect(_on_ace_destroyed)
	add_child(_ace)

	hud.flash_banner(tr("DUEL: %s") % tr(ace.name).to_upper())
	hud.radio(ace.taunt)
	Sound.start_flight_music()


func _process(delta: float) -> void:
	if not _finished:
		_elapsed += delta
	hud.set_status_text(tr("DUEL     TIME %02d:%02d") % [floori(_elapsed / 60.0), int(_elapsed) % 60])


func _on_player_damaged(amount: float, attacker: Aircraft) -> void:
	super(amount, attacker)
	_damage_taken += amount


func _on_player_destroyed(attacker: Aircraft) -> void:
	_finish(false, "You were shot down." if attacker else "You crashed.")


func _on_ace_destroyed(_attacker: Aircraft) -> void:
	_finish(true, tr("%s is going down!") % tr(Aces.ACES[ace_index].name))


func _finish(success: bool, reason: String) -> void:
	if _finished:
		return
	_finished = true
	hud.flash_banner("VICTORY" if success else "DEFEATED")
	var medals: Array[String] = []
	if success:
		medals = Profile.record_duel_win(Aces.ACES[ace_index].id)
	await get_tree().create_timer(DEBRIEF_DELAY).timeout
	Sound.stop_flight_music()
	Sound.play_music("victory" if success else "defeat")
	pause_menu.close()
	pause_menu.enabled = false
	hud.visible = false
	get_tree().paused = true

	var shots := player.guns.shots_fired
	var stats := [
		["Time", "%02d:%02d" % [floori(_elapsed / 60.0), int(_elapsed) % 60]],
		["Damage taken", "%d%%" % roundi(100.0 * minf(_damage_taken / player.stats.max_health, 1.0))],
		["Gun accuracy", "-" if shots == 0 else "%d%%" % roundi(100.0 * player_hits / shots)],
	]
	for id in medals:
		reason += "\n" + tr("MEDAL: %s") % tr(Medals.find(id).name)
	var debrief := DEBRIEF_SCENE.instantiate()
	add_child(debrief)
	debrief.setup(success, reason, stats, {}, null)
	debrief.set_return("Duels", DUELS_SCREEN)
	debrief.retry_pressed.connect(restart)
