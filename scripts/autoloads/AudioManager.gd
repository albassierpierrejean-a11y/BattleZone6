extends Node

# ─── Constants ───────────────────────────────────────────────────────────────
const POOL_SIZE        := 16
const BUS_MASTER       := "Master"
const BUS_SFX          := "SFX"
const BUS_MUSIC        := "Music"
const BUS_VOICE        := "Voice"

# ─── State ───────────────────────────────────────────────────────────────────
var _pool: Array[AudioStreamPlayer3D] = []
var _pool_index: int = 0
var _music_player: AudioStreamPlayer

func _ready() -> void:
	_setup_buses()
	_build_pool()
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = BUS_MUSIC
	add_child(_music_player)

func _setup_buses() -> void:
	if AudioServer.get_bus_index(BUS_SFX) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, BUS_SFX)
	if AudioServer.get_bus_index(BUS_MUSIC) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, BUS_MUSIC)
	if AudioServer.get_bus_index(BUS_VOICE) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, BUS_VOICE)

func _build_pool() -> void:
	for i in POOL_SIZE:
		var player := AudioStreamPlayer3D.new()
		player.bus = BUS_SFX
		player.max_distance = 100.0
		add_child(player)
		_pool.append(player)

# ─── Playback ─────────────────────────────────────────────────────────────────
func play_3d(stream: AudioStream, position: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not stream:
		return
	var player := _pool[_pool_index]
	_pool_index = (_pool_index + 1) % POOL_SIZE
	player.stream = stream
	player.global_position = position
	player.volume_db = volume_db
	player.pitch_scale = pitch + randf_range(-0.05, 0.05)
	player.play()

func play_ui(stream: AudioStream, volume_db: float = 0.0) -> void:
	if not stream:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.bus = BUS_SFX
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func play_music(stream: AudioStream, fade_time: float = 1.0) -> void:
	if _music_player.playing:
		var tween := create_tween()
		tween.tween_property(_music_player, "volume_db", -80.0, fade_time)
		await tween.finished
	_music_player.stream = stream
	_music_player.volume_db = 0.0
	_music_player.play()

func stop_music(fade_time: float = 1.0) -> void:
	var tween := create_tween()
	tween.tween_property(_music_player, "volume_db", -80.0, fade_time)
	await tween.finished
	_music_player.stop()

# ─── Volume Control ───────────────────────────────────────────────────────────
func set_master_volume(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_MASTER), linear_to_db(value))

func set_sfx_volume(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_SFX), linear_to_db(value))

func set_music_volume(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_MUSIC), linear_to_db(value))

func play_footstep(_position: Vector3, _movement_state: int) -> void:
	pass  # Assign AudioStream resources here when sound files are available
