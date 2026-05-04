extends EncounterAction
class_name ResetCameraAction

func _init():
	blocking = false

func run(encounterPoint : EncounterPoint) -> void:
	var player = Game.getPlayer()
	player.trackingSpeed = Player.DEFAULT_TRACKING_SPEED
	EventBus.releasePlayerTarget.emit()
	player.resetCamera()
