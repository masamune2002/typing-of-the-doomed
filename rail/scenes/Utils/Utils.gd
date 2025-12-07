extends Node

func isEventMidiNoteOnEvent(event : InputEvent) -> bool:
	if event is not InputEventMIDI:
		return false
	var midiEvent : InputEventMIDI = event
	if midiEvent.message == MIDI_MESSAGE_NOTE_ON:
		return true
	return false

func clearChildren(node : Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func generateRoot() -> int:
	var rng = RandomNumberGenerator.new()
	return rng.randi_range(60, 72)

func generateChord(difficulty : int) -> Chord:
	var root = generateRoot()
	return generateChordFromRoot(root, difficulty)

func generateChordFromRoot(root : int, difficulty : int) -> Chord:
	var possibleChords : Array[Dictionary] = getPossibleTargetChordTypes(difficulty)
	var randomChordType : Dictionary = possibleChords.pick_random()
	var chordToReturn : Chord = Chord.new()
	chordToReturn.setup(root, randomChordType)
	return chordToReturn

func generateScaleFromRoot(root : int, difficulty : int) -> Scale:
	var possibleChords : Array[Dictionary] = getPossibleTargetChordTypes(difficulty)
	var randomChordType : Dictionary = possibleChords.pick_random()
	var scaleToReturn : Scale = Scale.new()
	scaleToReturn.setup(root, randomChordType)
	return scaleToReturn

func midiPitchToNoteName(pitch : Pitch) -> String:
	return Constants.PITCH_NAMES[pitch.pitch % 12]

func midiChordToNoteName(chord : Chord) -> String:
	var rootPitch = chord.root
	var note = Constants.PITCH_NAMES[rootPitch % 12]
	var octave = int(rootPitch / 12.0) - 1
	return "%s%d%s" % [note, octave, chord.type.suffix]

func getPossibleTargetChordTypes(difficulty : int) -> Array[Dictionary]:
	var possibleChords : Array[Dictionary]= []
	for chord in Constants.CHORD_TYPES:
		if chord.difficulty == difficulty:
			possibleChords.append(chord)
	return possibleChords
