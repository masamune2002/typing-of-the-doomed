extends EncounterAction
class_name StopCameraAction

func run(encounterPoint : EncounterPoint) -> void:
	var player = Game.getPlayer()
	player.stopCameraMove(self)
