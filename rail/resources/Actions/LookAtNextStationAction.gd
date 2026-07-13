extends EncounterAction
class_name LookAtNextStationAction

## Turns the player toward this station's next station — a LookAtAction
## whose target is resolved from the station itself, so it needs no
## per-station NodePath configuration.

@export_range(1, 100) var speed : float = 50.0

func _speedToDuration() -> float:
	return 0.15 * (50.0 / max(speed, 1.0))

func run(encounterPoint : EncounterPoint) -> void:
	var station := encounterPoint as RailStation
	if station == null:
		push_warning("LookAtNextStationAction: encounter point is not a RailStation")
		finish()
		return
	var next = station.resolve_next_stations()
	if next.is_empty():
		# Route terminus — nothing to look toward
		finish()
		return
	var duration = _speedToDuration()
	var tween = Game.getPlayer().lookAtPosition(next[0].global_position, duration)
	if blocking and tween != null:
		await tween.finished
	finish()
