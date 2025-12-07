extends Weakness
class_name MidiWeakness

var scale : Scale
var targetRoot : int
var targetHit : bool

func _generateTargetRoot() -> int:
	var rng = RandomNumberGenerator.new()
	return rng.randi_range(60, 72)

func _midiPitchToNoteName(chord : Chord) -> String:
	var rootPitch = chord.root
	var note = Constants.PITCH_NAMES[rootPitch % 12]
	var octave = int(rootPitch / 12.0) - 1
	return "%s%d%s" % [note, octave, chord.type.suffix]

func receiveHit(payload : Variant) -> bool:
	if payload is Array[InputEventMIDI]:
		var midiSwitch : Array[InputEventMIDI] = payload
		for hitPoint : MidiHitPoint in hitPoints:
			if hitPoint.receiveHit(midiSwitch):
				targetHit = true
				updateLabel()
				break
	return targetHit
