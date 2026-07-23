extends Node
class_name TitleScreen

signal game_started(map_idx: int)
signal save_loaded(save_data: Dictionary)

var _menu : GameMenu = null

func _ready() -> void:
	_menu = preload("res://scenes/UI/GameMenu/GameMenu.tscn").instantiate()
	_menu.game_started.connect(func(idx):
		_stopMusic()
		game_started.emit(idx)
	)
	_menu.save_loaded.connect(func(data):
		_stopMusic()
		save_loaded.emit(data)
	)
	add_child(_menu)
	_playTitleMusic()

func _playTitleMusic() -> void:
	if not is_inside_tree():
		return
	# D_INTRO is the one song that plays once; vanilla's title music ends
	# and leaves the demo silence. playMidiMusic sets loop per call, so no
	# restore is needed for the songs that follow.
	Game.playMidiMusic("D_INTRO", false)

func _stopMusic() -> void:
	Game.stopMidiMusic()
