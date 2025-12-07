extends HitPoint
class_name MidiHitPoint

var target : MidiTarget

func setup(newTarget : MidiTarget) -> void:
	target = newTarget

func receiveHit(payload : Variant) -> bool:
	if !full || target == null:
		return false

	if payload is Array[InputEventMIDI]:
		var midiSwitch : Array[InputEventMIDI] = payload
		var isMatch = target.isMatch(midiSwitch)
		if isMatch:
			full = false
			return true
	return false

func toString() -> String:
	return Utils.midiPitchToNoteName(target)
