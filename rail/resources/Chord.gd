extends MidiTarget
class_name Chord

var pitches : Array[int] = []

func setup(new_root : int, new_scale_type : Dictionary) -> void:
	root = new_root
	type = new_scale_type
	_rebuild_cache()

func _rebuild_cache() -> void:
	pitches.clear()
	for i : int in type.intervals:
		pitches.append((root + i) % 12)
	# keep sorted & unique
	pitches.sort()
