extends Weapon
class_name MidiGun

var midiSwitch : Array[InputEventMIDI]
const MIDI_PITCH_MIN = 0
const MIDI_PITCH_MAX = 127

# Called when the node enters the scene tree for the first time.
func _ready():
	fireType = Enums.WEAPON_FIRE_TYPE.MIDI
	OS.open_midi_inputs()
	print(OS.get_connected_midi_inputs())
	midiSwitch = _initializeSwitch(midiSwitch)

func fire(event : InputEvent) -> Variant:
	if canFire(event):
		return _processMidiEvent(event)
	print('MIDI Gun can\'t fire!')
	return null

func _initializeSwitch(switch : Array[InputEventMIDI]):
	switch.resize(abs(MIDI_PITCH_MIN) + abs(MIDI_PITCH_MAX))
	for i in range(MIDI_PITCH_MIN, MIDI_PITCH_MAX):
		switch.fill(null)
	return switch

func canFire(inputEvent : InputEvent):
	if inputEvent is InputEventMIDI && inputEvent.message && inputEvent.pitch:
		return true
	return false

func _processMidiEvent(inputEvent) -> Variant:
	match inputEvent.message:
		MIDI_MESSAGE_NOTE_ON:
			midiSwitch[inputEvent.pitch] = inputEvent
		MIDI_MESSAGE_NOTE_OFF:
			midiSwitch[inputEvent.pitch] = null
		_:
			return
	#$MidiPlayer.receive_raw_midi_message(inputEvent)
	return midiSwitch
