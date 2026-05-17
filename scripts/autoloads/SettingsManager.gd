extends Node

const SAVE_PATH := "user://settings.cfg"

# ── Audio ─────────────────────────────────────────────────────────────────────
var volume_master: float = 1.0
var volume_music:  float = 0.7
var volume_sfx:    float = 0.9

# ── Graphics ──────────────────────────────────────────────────────────────────
var graphics_preset: int  = 3          # GraphicsManager.Preset.HIGH
var fov:             float = 75.0
var vsync:           bool  = true
var fullscreen:      bool  = false
var max_fps:         int   = 0         # 0 = illimité

# ── Gameplay ──────────────────────────────────────────────────────────────────
var mouse_sensitivity: float = 0.15
var ads_sensitivity:   float = 0.08
var invert_y:          bool  = false

func _ready() -> void:
	_load()
	_apply_all()

func _apply_all() -> void:
	_apply_audio()
	_apply_graphics()
	_apply_display()

# ── Audio application ─────────────────────────────────────────────────────────
func _apply_audio() -> void:
	AudioManager.set_master_volume(volume_master)
	AudioManager.set_music_volume(volume_music)
	AudioManager.set_sfx_volume(volume_sfx)

func set_volume_master(v: float) -> void:
	volume_master = clampf(v, 0.0, 1.0)
	AudioManager.set_master_volume(volume_master)

func set_volume_music(v: float) -> void:
	volume_music = clampf(v, 0.0, 1.0)
	AudioManager.set_music_volume(volume_music)

func set_volume_sfx(v: float) -> void:
	volume_sfx = clampf(v, 0.0, 1.0)
	AudioManager.set_sfx_volume(volume_sfx)

# ── Graphics application ──────────────────────────────────────────────────────
func _apply_graphics() -> void:
	GraphicsManager.apply_preset(graphics_preset)
	GraphicsManager.set_fov(fov)

func _apply_display() -> void:
	GraphicsManager.set_vsync(vsync)
	GraphicsManager.set_max_fps(max_fps)
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen \
			  else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)

func set_graphics_preset(preset: int) -> void:
	graphics_preset = preset
	GraphicsManager.apply_preset(preset)

func set_fov(v: float) -> void:
	fov = clampf(v, 55.0, 110.0)
	GraphicsManager.set_fov(fov)

func set_vsync(v: bool) -> void:
	vsync = v
	GraphicsManager.set_vsync(v)

func set_fullscreen(v: bool) -> void:
	fullscreen = v
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if v \
			  else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)

func set_max_fps(v: int) -> void:
	max_fps = v
	GraphicsManager.set_max_fps(v)

# ── Gameplay application ──────────────────────────────────────────────────────
func set_mouse_sensitivity(v: float) -> void:
	mouse_sensitivity = clampf(v, 0.01, 1.0)

func set_ads_sensitivity(v: float) -> void:
	ads_sensitivity = clampf(v, 0.01, 1.0)

func set_invert_y(v: bool) -> void:
	invert_y = v

# ── Persistence ───────────────────────────────────────────────────────────────
func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio",    "master",           volume_master)
	cfg.set_value("audio",    "music",            volume_music)
	cfg.set_value("audio",    "sfx",              volume_sfx)
	cfg.set_value("graphics", "preset",           graphics_preset)
	cfg.set_value("graphics", "fov",              fov)
	cfg.set_value("graphics", "vsync",            vsync)
	cfg.set_value("graphics", "fullscreen",       fullscreen)
	cfg.set_value("graphics", "max_fps",          max_fps)
	cfg.set_value("gameplay", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("gameplay", "ads_sensitivity",   ads_sensitivity)
	cfg.set_value("gameplay", "invert_y",          invert_y)
	cfg.save(SAVE_PATH)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	volume_master      = cfg.get_value("audio",    "master",           volume_master)
	volume_music       = cfg.get_value("audio",    "music",            volume_music)
	volume_sfx         = cfg.get_value("audio",    "sfx",              volume_sfx)
	graphics_preset    = cfg.get_value("graphics", "preset",           graphics_preset)
	fov                = cfg.get_value("graphics", "fov",              fov)
	vsync              = cfg.get_value("graphics", "vsync",            vsync)
	fullscreen         = cfg.get_value("graphics", "fullscreen",       fullscreen)
	max_fps            = cfg.get_value("graphics", "max_fps",          max_fps)
	mouse_sensitivity  = cfg.get_value("gameplay", "mouse_sensitivity", mouse_sensitivity)
	ads_sensitivity    = cfg.get_value("gameplay", "ads_sensitivity",   ads_sensitivity)
	invert_y           = cfg.get_value("gameplay", "invert_y",          invert_y)
