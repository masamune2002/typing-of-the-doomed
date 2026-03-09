extends Resource
class_name EncounterAction

@export var blocking = true
var _finished : bool = false
signal finished

func run(encounterPoint : EncounterPoint) -> void:
	push_warning('EncounterAction.run() not implemented')

func finish():
	_finished = true
	finished.emit()

func isFinished() -> bool:
	return _finished
