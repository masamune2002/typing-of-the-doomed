extends EncounterAction
class_name SleepAction

@export var milliseconds : int = 500

func run(encounterPoint: EncounterPoint) -> void:
	# If the duration is zero or negative, finish immediately.
	if milliseconds <= 0:
		finish()
		return

	var seconds := float(milliseconds) / 1000.0
	# Use the EncounterPoint to reach the SceneTree (Resources can't call get_tree()).
	await Game.createTimer(seconds).timeout
	finish()
