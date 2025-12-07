extends MidiWeakness
class_name MidiChordWeakness

func _generateTargetChord(difficulty : int) -> Chord:
	var possibleChords : Array[Dictionary] = _getPossibleTargetChordTypes(difficulty)
	var randomChordType : Dictionary = possibleChords.pick_random()
	var chordToReturn : Chord = Chord.new()
	chordToReturn.setup(targetRoot, randomChordType)
	return chordToReturn

func _getPossibleTargetChordTypes(difficulty : int) -> Array[Dictionary]:
	var possibleChords : Array[Dictionary]= []
	for chord in Constants.CHORD_TYPES:
		if chord.difficulty == difficulty:
			possibleChords.append(chord)
	return possibleChords

func setup(difficulty) -> void:
	targetHit = false
	weaknessType = Enums.WEAPON_FIRE_TYPE.MIDI
	targetRoot = _generateTargetRoot()
	var newChord = _generateTargetChord(difficulty)
	var newHitPoint = MidiHitPoint.new()
	newHitPoint.setup(newChord)
	hitPoints.append(newHitPoint)
	updateLabel()

func receiveHit(payload : Variant) -> bool:
	if payload is Array[InputEventMIDI]:
		var midiSwitch : Array[InputEventMIDI] = payload
		for hitPoint : MidiHitPoint in hitPoints:
			if hitPoint.receiveHit(midiSwitch):
				targetHit = true
				updateLabel()
				break
	return targetHit
