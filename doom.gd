extends Node3D

const START_LOCATIONS = [
	{
		"x": 0,
		"y": 0,
		"z": 115
	}, 
	{
		"x": 0,
		"y": 3,
		"z": 0
	}, 
	{
		"x": -47,
		"y": 4,
		"z": 104
	}
]

const MAP_IDX = 0

# WadRuntimeLoader.gd
func load_wad(path: String, map_idx: int) -> Node3D:
	# ... all the existing logic ...
	var map_node: Node3D = _loader.createMap(map_name, meta, false, get_tree().get_root())
	if map_node.get_parent():
		map_node.get_parent().remove_child(map_node)
	add_child(map_node)

	return map_node


func _ready() -> void:
	var loader := WadRuntimeLoader.new()
	add_child(loader)
	var app_dir = OS.get_executable_path().get_base_dir().get_base_dir().get_base_dir()
	var file_path = app_dir.path_join("../DOOM.wad")
	var wad_file = FileAccess.open(file_path, FileAccess.READ)
	if !wad_file:
		file_path = "res://DOOM.wad"
		wad_file = FileAccess.open(file_path, FileAccess.READ)
	
	loader.load_wad(file_path, MAP_IDX)
