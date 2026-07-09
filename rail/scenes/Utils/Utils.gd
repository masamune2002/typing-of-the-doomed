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

# ---- Label view clamping ----------------------------------------------
# World-space Label3Ds anchor above their owner (door center, enemy head,
# key), so walking right up to the owner pushes the label out of the top of
# the view — or fully behind the camera when an enemy is at melee range.
# The player then has nothing to type at exactly the moment they need it
# (a door closed in their face, a pinky in melee). These helpers keep the
# label readable at close range:
#
# - labelCloseBypass: visibility checks treat a close, in-front owner as
#   on-screen even if its label anchor is not.
# - clampLabelsToView: while the natural anchor sits outside a cone around
#   the camera forward axis (but still in the front hemisphere), the whole
#   label group is pulled to the cone edge in the anchor's direction — it
#   tracks the view like a HUD element but keeps pointing at its owner, so
#   several close targets don't stack on one screen point. A minimum
#   distance keeps the pulled-in label from filling the screen.

const LABEL_CONE_DEG := 20.0    # labels stay within this angle of view center
const LABEL_MIN_DIST := 1.2     # never closer to the camera than this
const LABEL_CLOSE_RANGE := 2.5  # bypass on-screen checks within this range

func labelCloseBypass(entity : Node3D) -> bool:
	var player = Game.getPlayer()
	if player == null:
		return false
	if entity.global_position.distance_to(player.global_position) > LABEL_CLOSE_RANGE:
		return false
	var camera : Camera3D = entity.get_viewport().get_camera_3d()
	if camera == null:
		return false
	var flat_fwd : Vector3 = -camera.global_transform.basis.z
	flat_fwd.y = 0
	var flat_to : Vector3 = entity.global_position - camera.global_position
	flat_to.y = 0
	# Overlapping bodies (an enemy at melee range) always count as in front;
	# otherwise require the front hemisphere so targets behind the player
	# still hide and release as before.
	return flat_to.length() < 0.4 or flat_fwd.dot(flat_to) >= 0.0

func clampLabelsToView(entity : Node3D, labels : Array, home_locals : Array) -> void:
	var camera : Camera3D = entity.get_viewport().get_camera_3d()
	if camera == null or labels.is_empty() or home_locals.is_empty():
		return
	var anchor : Vector3 = entity.to_global(home_locals[0])
	var cam_pos : Vector3 = camera.global_position
	var forward : Vector3 = -camera.global_transform.basis.z
	var to_anchor : Vector3 = anchor - cam_pos
	var dist : float = to_anchor.length()
	var delta := Vector3.ZERO
	if dist > 0.001:
		var dir : Vector3 = to_anchor / dist
		var angle : float = forward.angle_to(dir)
		var max_angle : float = deg_to_rad(LABEL_CONE_DEG)
		if angle > max_angle and angle < PI * 0.5:
			var axis : Vector3 = forward.cross(dir)
			if axis.length() < 0.001:
				axis = camera.global_transform.basis.y
			axis = axis.normalized()
			var clamped_dir : Vector3 = forward.rotated(axis, max_angle)
			delta = (cam_pos + clamped_dir * maxf(dist, LABEL_MIN_DIST)) - anchor
		elif dist < LABEL_MIN_DIST:
			delta = dir * (LABEL_MIN_DIST - dist)
	for i in labels.size():
		var label = labels[i]
		if label == null or i >= home_locals.size():
			continue
		label.global_position = entity.to_global(home_locals[i]) + delta
