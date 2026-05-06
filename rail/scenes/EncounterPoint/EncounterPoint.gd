@tool
extends RailMarker
class_name EncounterPoint

## A scripted RailMarker: runs startActions on entry, polls conditions
## while active, runs endActions and finalizes once they pass.

@export var startActions : Array[EncounterAction] = []
@export var endActions : Array[EncounterAction] = []

var _starting : bool = false
var _ending : bool = false
var conditionsMet : bool
var active : bool

func _process(_delta: float) -> void:
	if !active or _starting or _ending:
		return
	_checkConditions()
	if conditionsMet:
		endEncounter()

func _checkConditions() -> void:
	conditionsMet = _checkConditionsOnce()

func _on_player_entered(player: Player) -> void:
	player.setCurrentEncounter(self)

func _runActions(actions : Array[EncounterAction]) -> void:
	for action in actions:
		if action == null:
			continue
		action._finished = false
		action.run(self)
		if action.blocking and !action.isFinished():
			await action.finished

func startEncounter() -> void:
	_has_triggered = true
	EventBus.startEncounter.emit()
	active = true
	_starting = true
	await _runActions(startActions)
	_starting = false

func endEncounter() -> void:
	_ending = true
	await _runActions(endActions)
	active = false
	_ending = false
