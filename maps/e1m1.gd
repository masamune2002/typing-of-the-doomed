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

const MAP_IDX = 1

func _ready() -> void:
	var loader := WadRuntimeLoader.new()
	add_child(loader)
	loader.load_wad("res://DOOM.WAD", MAP_IDX)
	var start_location = START_LOCATIONS[MAP_IDX]
	$Camera3D.position.x = start_location.x
	$Camera3D.position.y = start_location.y
	$Camera3D.position.z = start_location.z
	#$Camera3D.rotation.y = 90
