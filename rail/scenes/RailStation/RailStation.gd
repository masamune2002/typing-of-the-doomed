@tool
extends EncounterPoint
class_name RailStation

signal station_changed

@export var next_stations: Array[NodePath] = []:
	set(v):
		next_stations = v
		call_deferred("emit_signal", "station_changed")

## If true, this station can interrupt an in-progress encounter.
@export var blocking: bool = false

@export_tool_button("Add Next Station") var _add_next = _on_add_next_station
@export_tool_button("Find Next Station") var _find_next = _on_find_next_station
@export_tool_button("Find Previous Station") var _find_prev = _on_find_prev_station

func _ready() -> void:
	if disc_color == Color(0, 0, 0, 0):
		disc_color = Color.from_hsv(randf(), 0.7, 0.9)
	super._ready()
	if Engine.is_editor_hint():
		add_to_group("rail_stations")
		# When you move the Station in the editor, notify network
		set_process(true)

func _process(delta: float) -> void:
	super._process(delta)
	if !Engine.is_editor_hint():
		return
	# Poll for transform changes in editor (simple & robust)
	if is_transform_changed():
		call_deferred("emit_signal", "station_changed")

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

func _on_add_next_station() -> void:
	if !Engine.is_editor_hint():
		return

	var scene := load("res://rail/scenes/RailStation/RailStation.tscn") as PackedScene
	var new_station: RailStation = scene.instantiate()

	# Name it sequentially
	var siblings := get_parent().get_children()
	var idx := siblings.size()
	new_station.name = "Station%d" % idx

	# Position offset: 3 units along the station's forward (-Z) direction
	new_station.transform.origin = transform.origin + (-global_transform.basis.z.normalized() * 3.0)

	# Give the new station a fresh random disc color so it's visually
	# distinct from its parent. The scene's saved disc_color would
	# otherwise suppress the randomize-on-ready fallback.
	new_station.disc_color = Color.from_hsv(randf(), 0.7, 0.9)

	# Match the generator convention: stations fire once. Re-triggerable
	# stations re-run their encounter when the player crosses their disc.
	new_station.one_shot = true

	# Capture the current next stations before rewiring: the new station is
	# inserted into the chain (A -> B becomes A -> C -> B), not appended as
	# a dead end.
	var old_next := resolve_next_stations()

	# Add as sibling under the same parent (Stations container)
	get_parent().add_child(new_station)
	if get_tree() != null and get_tree().edited_scene_root != null:
		new_station.owner = get_tree().edited_scene_root

	# The new station inherits this station's old next stations (paths must
	# be relative to the new station, not this one)
	var inherited: Array[NodePath] = []
	for s in old_next:
		inherited.append(new_station.get_path_to(s))
	new_station.next_stations = inherited

	# Point this station to the new one
	next_stations = [get_path_to(new_station)]

	# Append AdvanceToNextStationAction to endActions if not already present
	var has_advance := false
	for action in endActions:
		if action is AdvanceToNextStationAction:
			has_advance = true
			break
	if !has_advance:
		var advance := AdvanceToNextStationAction.new()
		endActions.append(advance)

	# The inserted station needs an advance action to keep the route flowing
	# to the inherited next station. The RailStation scene already ships one
	# in endActions by default — only append if it's ever removed from the
	# scene. A duplicate advance re-runs the just-completed path on arrival
	# and drags the player backward.
	if !inherited.is_empty():
		var new_has_advance := false
		for action in new_station.endActions:
			if action is AdvanceToNextStationAction:
				new_has_advance = true
				break
		if !new_has_advance:
			new_station.endActions.append(AdvanceToNextStationAction.new())

	call_deferred("emit_signal", "station_changed")
	_select_and_focus(new_station)

func _select_and_focus(node: Node) -> void:
	# Defer to avoid clearing selection while the button click signal is still propagating
	_deferred_select.call_deferred(node)

func _deferred_select(node: Node) -> void:
	var selection := EditorInterface.get_selection()
	selection.clear()
	selection.add_node(node)
	EditorInterface.edit_node(node)

func _on_find_next_station() -> void:
	if !Engine.is_editor_hint():
		return
	var stations = resolve_next_stations()
	if stations.is_empty():
		push_warning("No next station set")
		return
	var next = stations[0]
	_select_and_focus(next)

func _on_find_prev_station() -> void:
	if !Engine.is_editor_hint():
		return
	# Find any station that lists this one in its next_stations
	for s in get_tree().get_nodes_in_group("rail_stations"):
		if s == self:
			continue
		for np in s.next_stations:
			var target = s.get_node_or_null(np)
			if target == self:
				_select_and_focus(s)
				return
	push_warning("No previous station found")

func _on_player_entered(player: Player) -> void:
	# While the rail is driving the player, stations are entered via path
	# completion (Player watches progress_ratio), never via the trigger
	# area. Without this guard, riding through the disc of the station
	# just departed re-runs its encounter, whose advance action restarts
	# the path — yanking the player backward to the follow point.
	if player._moving:
		return
	if player.currentEncounter != null and player.currentEncounter.active and not blocking:
		return
	super._on_player_entered(player)

func resolve_next_stations() -> Array[RailStation]:
	var out: Array[RailStation] = []
	for p in next_stations:
		if p != NodePath():
			var n = get_node_or_null(p)
			if n is RailStation:
				out.append(n)
	return out
