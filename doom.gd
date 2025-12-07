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
var player : Node = null
var railPlayer : Node = null

func _ready() -> void:
	var loader := WadRuntimeLoader.new()
	add_child(loader)
	loader.mapCreated.connect(_onMapCreated)
	loader.playerCreated.connect(_onPlayerCreated)
	var app_dir = OS.get_executable_path().get_base_dir().get_base_dir().get_base_dir()
	var file_path = app_dir.path_join("../DOOM.wad")
	var wad_file = FileAccess.open(file_path, FileAccess.READ)
	if !wad_file:
		file_path = "res://DOOM.wad"
		wad_file = FileAccess.open(file_path, FileAccess.READ)

	loader.load_wad(file_path, MAP_IDX)

func _onMapCreated() -> void:
	print('loaded map')

func _onPlayerCreated(createdPlayer : Node) -> void:
	createdPlayer.name = 'playerguy'
	player = createdPlayer
	railPlayer = createdPlayer.get_node('Player')
