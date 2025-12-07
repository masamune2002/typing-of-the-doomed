extends MidiTarget
class_name Scale

var pitches : Array[Pitch]

func isMatch(midiSwitch : Array[InputEventMIDI]) -> bool:
	var targetHit = false
	for pitch : Pitch in pitches:
		if pitch.isMatch(midiSwitch):
			targetHit = true
	return targetHit

func setup(newRoot : int, newScaleType : Dictionary):
	root = newRoot
	type = newScaleType
	for interval in type.intervals:
		var pitch : Pitch = Pitch.new()
		pitch.setup(interval + root)
		pitches.append(pitch)

func toString() -> String:
	var nameString : String = ""
	for pitch : Pitch in pitches:
		nameString += pitch.toString()
		nameString += " "
	return nameString
