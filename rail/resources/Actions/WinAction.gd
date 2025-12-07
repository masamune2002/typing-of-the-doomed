extends EncounterAction
class_name WinAction

func run(encounterPoint : EncounterPoint) -> void:
	Game.getPlayer().win()
	finished.emit()
