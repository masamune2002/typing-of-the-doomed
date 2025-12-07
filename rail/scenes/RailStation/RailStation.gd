@tool
extends Node3D
class_name RailStation

signal station_changed

@export var next_stations: Array[NodePath] = []:
	set(v):
		next_stations = v
		emit_signal("station_changed")

func _ready() -> void:
	if Engine.is_editor_hint():
		add_to_group("rail_stations")
		# When you move the Station in the editor, notify network
		set_process(true)

func _process(_delta: float) -> void:
	if !Engine.is_editor_hint():
		return
	# Poll for transform changes in editor (simple & robust)
	if is_transform_changed():
		emit_signal("station_changed")

func is_transform_changed() -> bool:
	# Editor polling trick: cache & compare
	if !has_meta("_last_xform"):
		set_meta("_last_xform", global_transform)
		return true
	var last: Transform3D = get_meta("_last_xform")
	if last != global_transform:
		set_meta("_last_xform", global_transform)
		return true
	return false

func resolve_next_stations() -> Array[RailStation]:
	var out: Array[RailStation] = []
	for p in next_stations:
		if p != NodePath():
			var n = get_node_or_null(p)
			if n is RailStation:
				out.append(n)
	return out
