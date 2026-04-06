extends Node3D

func _ready() -> void:
	var loader := WadRuntimeLoader.new()
	add_child(loader)
	loader.geometry_only = false
	var app_dir = OS.get_executable_path().get_base_dir().get_base_dir().get_base_dir()
	var file_path = app_dir.path_join("../DOOM.wad")
	var wad_file = FileAccess.open(file_path, FileAccess.READ)
	if !wad_file:
		file_path = "res://DOOM.wad"
	loader.load_wad(file_path, 0)
