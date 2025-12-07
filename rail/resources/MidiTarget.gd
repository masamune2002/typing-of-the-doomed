extends Resource
class_name MidiTarget

var type : Dictionary
var root : int

func isMatch(midiSwitch : Array[InputEventMIDI]) -> bool:
	return false

func toString() -> String:
	return ""
