extends EncounterAction
class_name StopCameraAction

func run(_encounterPoint : EncounterPoint) -> void:
	var player = Game.getPlayer()
	player.stopCameraMove(self)
