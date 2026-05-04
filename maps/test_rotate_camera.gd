extends Node3D

func _ready() -> void:
	# Initialize WAD loader before children need sprites
	var loader := WadRuntimeLoader.new()
	add_child(loader)
	loader.geometry_only = true
	Game.setWadLoader(loader)
	var app_dir = OS.get_executable_path().get_base_dir().get_base_dir().get_base_dir()
	var wad_path = app_dir.path_join("../DOOM.wad")
	var wad_file = FileAccess.open(wad_path, FileAccess.READ)
	if !wad_file:
		wad_path = "res://DOOM.wad"
	loader.init_wad(wad_path)
	loader.mapCreated.connect(_onMapCreated)
	loader.load_map("E1M1")

func _onMapCreated() -> void:
	# WAD sprites are now available — reload the player's HUD
	var player = Game.getPlayer()
	if player != null:
		player._playerUi.setup(player.playerCharacter)
