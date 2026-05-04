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
	var loader = Game.wadLoader
	if loader == null or loader._loader == null:
		return
	var resource_manager = loader._loader.get_node_or_null("ResourceManager")
	if resource_manager == null:
		return
	var midi_data = resource_manager.fetchMidiOrMus("D_INTRO")
	if midi_data == null:
		return
	var midi_player = ENTG.fetchMidiPlayer(get_tree())
	ENTG.setMidiPlayerData(midi_player, midi_data)
	if midi_player != null and is_instance_valid(midi_player):
		if midi_player.get_parent() == null:
			midi_player.ready.connect(midi_player.play)
			get_tree().get_root().call_deferred("add_child", midi_player)
		else:
			midi_player.play()

func _stopMusic() -> void:
	var tree = get_tree()
	if tree.has_meta("midiPlayer"):
		var midi_player = tree.get_meta("midiPlayer")
		if midi_player != null and is_instance_valid(midi_player):
			midi_player.stop()
