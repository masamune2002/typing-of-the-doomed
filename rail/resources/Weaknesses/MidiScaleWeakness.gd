extends MidiWeakness
class_name MidiScaleWeakness

var targetScale : Scale

func _generateTargetScale(root : int) -> Scale:
	var scaleToReturn = Scale.new()
	scaleToReturn.setup(root, Constants.SCALE_TYPES[0])
	return scaleToReturn

func setup(difficulty: int) -> void:
	targetHit = false
	weaknessType = Enums.WEAPON_FIRE_TYPE.MIDI
	targetRoot = _generateTargetRoot()
	targetScale = _generateTargetScale(targetRoot)

	for pitch : Pitch in targetScale.pitches:
		var newHitPoint = MidiHitPoint.new()
		newHitPoint.setup(pitch)
		hitPoints.append(newHitPoint)
	updateLabel()

func receiveHit(payload : Variant) -> bool:
	if payload is Array[InputEventMIDI]:
		var midiSwitch : Array[InputEventMIDI] = payload
		for hitPoint : MidiHitPoint in hitPoints:
			if hitPoint.full && hitPoint.receiveHit(midiSwitch):
				targetHit = true
				updateLabel()
				break
	return targetHit

func updateLabel() -> void:
	var newLabelText : String = ""
	for hitPoint : HitPoint in hitPoints:
		if hitPoint.full:
			newLabelText = str(newLabelText, hitPoint.toString(), " ")
	weaknessLabelText = newLabelText
