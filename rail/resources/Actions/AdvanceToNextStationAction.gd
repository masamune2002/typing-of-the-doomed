@tool
extends EncounterAction
class_name AdvanceToNextStationAction

@export_range(1, 100) var speed: float = 50.0
## If set, reads this Game variable to pick which next_stations index to follow.
@export var station_variable: String = ""

func run(encounterPoint: EncounterPoint) -> void:
	if Engine.is_editor_hint():
		return
	_finished = false
	if not encounterPoint is RailStation:
		push_warning("AdvanceToNextStationAction: encounterPoint is not a RailStation")
		finish()
		return

	var station: RailStation = encounterPoint as RailStation
	var next_station: RailStation = _pick_next(station)
	if next_station == null:
		push_warning("AdvanceToNextStationAction: no next station found")
		finish()
		return

	var rail_path: RailPath = _find_rail_path(station, next_station)
	if rail_path == null:
		push_warning("AdvanceToNextStationAction: no RailPath to %s" % next_station.name)
		finish()
		return

	var player = Game.getPlayer()
	var railSpeed = player.moveSpeed * (speed / 50.0)
	player.lookAtPosition(next_station.global_position, 0.25)
	player.startCameraMove(rail_path, self, railSpeed)

func _pick_next(station: RailStation) -> RailStation:
	var stations = station.resolve_next_stations()
	if stations.is_empty():
		return null
	if stations.size() == 1:
		return stations[0]
	if station_variable != "":
		var idx = Game.getVar(station_variable, 0)
		if idx is int and idx >= 0 and idx < stations.size():
			return stations[idx]
	return stations[0]

func _find_rail_path(from: RailStation, to: RailStation) -> RailPath:
	for node in from.get_tree().get_nodes_in_group("rail_paths"):
		if node is RailPath:
			var from_node = node.get_node_or_null(node.from_station)
			var to_node = node.get_node_or_null(node.to_station)
			if from_node == from and to_node == to:
				return node
	return null
