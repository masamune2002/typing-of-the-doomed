extends MidiTarget
class_name Pitch

var pitch : int

func setup(newPitch : int) -> void:
	pitch = newPitch

func isMatch(midiSwitch : Array[InputEventMIDI]) -> bool:
	if midiSwitch[pitch] != null:
		return true
	return false

func toString() -> String:
	return Utils.midiPitchToNoteName(self)

func minorSecond():
	return pitch + 1

func majorSecond():
	return pitch + 2

func minorThird():
	return pitch + 3

func majorTird():
	return pitch + 4

func perfectFourth():
	return pitch + 5

func perfectFifth():
	return pitch + 7

func minorSixth():
	return pitch + 8

func majorSixth():
	return pitch + 9

func minorSeventh():
	return pitch + 10

func majorSeventh():
	return pitch + 11

func perfectOctave():
	return pitch + 12
