extends EncounterAction
class_name ShowDialogAction

@export var dialogToShow : Dialog

func run(encounterPoint : EncounterPoint) -> void:
	if dialogToShow == null || dialogToShow.lines.size() > 0:
			var player : Player = Game.getPlayer()
			if is_instance_valid(player):
				dialogToShow.actionToFinish = self
				player.showDialog(dialogToShow)
