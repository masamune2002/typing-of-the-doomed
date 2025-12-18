extends Node3D

const FIRST_MAP_IDX = 0

func _ready() -> void:
	var loader := WadRuntimeLoader.new()
	add_child(loader)
	loader.mapCreated.connect(_onMapCreated)
	var app_dir = OS.get_executable_path().get_base_dir().get_base_dir().get_base_dir()
	var file_path = app_dir.path_join("../DOOM.wad")
	var wad_file = FileAccess.open(file_path, FileAccess.READ)
	if !wad_file:
		file_path = "res://DOOM.wad"
		wad_file = FileAccess.open(file_path, FileAccess.READ)

	loader.load_wad(file_path, FIRST_MAP_IDX)

func _onMapCreated() -> void:
	print_debug('loaded map')
