extends Node

const SETTINGS_PATH = "user://settings.cfg"

var master_volume : float = 1.0
var music_volume : float = 1.0
var sfx_volume : float = 1.0
var fullscreen : bool = true
var vsync : bool = true
var last_wad_path : String = ""
var head_bob : float = 1.0
var weapon_sway : float = 1.0
var debug_show_thing_ids : bool = false
var debug_tracking : bool = false
var debug_reticle : bool = false
var debug_show_stations : bool = false
var debug_show_rails : bool = false
var debug_skip_encounters : bool = false
var debug_superspeed : bool = false
var debug_wasd : bool = false
var debug_wasd_paused : bool = false
var _tracking_timer : float = 0.0

func _ready() -> void:
	load_settings()
	apply_settings()

func _process(delta: float) -> void:
	if not debug_tracking:
		return
	_tracking_timer += delta
	if _tracking_timer >= 0.5:
		_tracking_timer = 0.0
		var player = Game.getPlayer()
		if player == null:
			return
		var gp = player.global_position
		var lp = player.position
		var cr = player._cameraRig.rotation_degrees
		print("[TRACK] global=(%.2f, %.2f, %.2f) local=(%.2f, %.2f, %.2f) cam_rot=(%.2f, %.2f, %.2f)" % [gp.x, gp.y, gp.z, lp.x, lp.y, lp.z, cr.x, cr.y, cr.z])

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE and debug_wasd:
			debug_wasd_paused = !debug_wasd_paused
			print("[DEBUG] WASD movement %s" % ("PAUSED" if debug_wasd_paused else "RESUMED"))
			return
	if not debug_tracking:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			var player = Game.getPlayer()
			if player == null:
				return
			var gp = player.global_position
			var cr = player._cameraRig.rotation_degrees
			print("[TRACK_STATION] global=(%.2f, %.2f, %.2f) cam_rot=(%.2f, %.2f, %.2f)" % [gp.x, gp.y, gp.z, cr.x, cr.y, cr.z])

func load_settings() -> void:
	var config = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	master_volume = config.get_value("audio", "master_volume", 1.0)
	music_volume = config.get_value("audio", "music_volume", 1.0)
	sfx_volume = config.get_value("audio", "sfx_volume", 1.0)
	fullscreen = config.get_value("video", "fullscreen", true)
	vsync = config.get_value("video", "vsync", true)
	last_wad_path = config.get_value("general", "last_wad_path", "")
	head_bob = config.get_value("gameplay", "head_bob", 1.0)
	weapon_sway = config.get_value("gameplay", "weapon_sway", 1.0)
	debug_show_thing_ids = config.get_value("debug", "show_thing_ids", false)
	debug_tracking = config.get_value("debug", "tracking", false)
	debug_reticle = config.get_value("debug", "reticle", false)
	debug_show_stations = config.get_value("debug", "show_stations", false)
	debug_show_rails = config.get_value("debug", "show_rails", false)
	debug_skip_encounters = config.get_value("debug", "skip_encounters", false)
	debug_superspeed = config.get_value("debug", "superspeed", false)
	debug_wasd = config.get_value("debug", "wasd", false)

func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("video", "fullscreen", fullscreen)
	config.set_value("video", "vsync", vsync)
	config.set_value("general", "last_wad_path", last_wad_path)
	config.set_value("gameplay", "head_bob", head_bob)
	config.set_value("gameplay", "weapon_sway", weapon_sway)
	config.set_value("debug", "show_thing_ids", debug_show_thing_ids)
	config.set_value("debug", "tracking", debug_tracking)
	config.set_value("debug", "reticle", debug_reticle)
	config.set_value("debug", "show_stations", debug_show_stations)
	config.set_value("debug", "show_rails", debug_show_rails)
	config.set_value("debug", "skip_encounters", debug_skip_encounters)
	config.set_value("debug", "superspeed", debug_superspeed)
	config.set_value("debug", "wasd", debug_wasd)
	config.save(SETTINGS_PATH)

func apply_settings() -> void:
	_apply_audio()
	_apply_video()

func _apply_audio() -> void:
	var master_idx = AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		AudioServer.set_bus_volume_db(master_idx, linear_to_db(master_volume))

	var music_idx = AudioServer.get_bus_index("Music")
	if music_idx >= 0:
		AudioServer.set_bus_volume_db(music_idx, linear_to_db(music_volume))

	var sfx_idx = AudioServer.get_bus_index("SFX")
	if sfx_idx >= 0:
		AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(sfx_volume))

func _apply_video() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)

	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_audio()

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_audio()

func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_audio()

func set_head_bob(value: float) -> void:
	head_bob = clampf(value, 0.0, 1.0)

func set_weapon_sway(value: float) -> void:
	weapon_sway = clampf(value, 0.0, 1.0)

func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply_video()

func set_vsync(value: bool) -> void:
	vsync = value
	_apply_video()
