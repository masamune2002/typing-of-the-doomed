extends SleepAction
class_name SleepForTargetsAction

## SleepAction that only sleeps while there is something on screen worth
## firing at (enemy, item, switch...). Put one before an
## AdvanceToNextStationAction so the player gets a beat to grab visible
## items before the rail rolls on - and no dead wait when there's nothing.

func run(encounterPoint : EncounterPoint) -> void:
	var player = Game.getPlayer()
	if player == null or player._getVisibleTargets().is_empty():
		finish()
		return
	await super.run(encounterPoint)
