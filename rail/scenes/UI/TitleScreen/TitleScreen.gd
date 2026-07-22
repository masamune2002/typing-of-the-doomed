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
	# Give the OS audio pipeline a beat before the first MIDI play: starting
	# the synth inside the process's first frames hard-crashed exported
	# Windows builds on the auto-boot route, while routes that reached the
	# title after human-speed picker clicks never did. A second's silence on
	# the title screen is imperceptible.
	get_tree().create_timer(TITLE_MUSIC_DELAY).timeout.connect(_playTitleMusic)

const TITLE_MUSIC_DELAY := 1.0

func _playTitleMusic() -> void:
	if not is_inside_tree():
		return
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
		if midi_player.is_inside_tree():
			midi_player.play()
		else:
			# fetchMidiPlayer already scheduled its own deferred add_child;
			# adding again here is what spammed "Can't add child 'MidiPlayer'
			# to 'root', already has a parent" on every boot
			midi_player.ready.connect(midi_player.play, CONNECT_ONE_SHOT)

func _stopMusic() -> void:
	var tree = get_tree()
	if tree.has_meta("midiPlayer"):
		var midi_player = tree.get_meta("midiPlayer")
		if midi_player != null and is_instance_valid(midi_player):
			midi_player.stop()
