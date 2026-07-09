extends EncounterAction
class_name WinAction

func run(_encounterPoint : EncounterPoint) -> void:
	Game.getPlayer().win()
	finished.emit()
