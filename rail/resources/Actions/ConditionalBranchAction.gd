extends EncounterAction
class_name ConditionalBranchAction

@export var variable_name: String = ""
@export var expected_value: String = "true"
@export var if_true_actions: Array[EncounterAction] = []
@export var if_false_actions: Array[EncounterAction] = []

func run(encounterPoint: EncounterPoint) -> void:
	_finished = false
	var current = Game.getVar(variable_name)
	var condition_met = (current == SetVariableAction._parse_value(expected_value))

	var actions_to_run: Array[EncounterAction]
	if condition_met:
		actions_to_run = if_true_actions
	else:
		actions_to_run = if_false_actions

	for action in actions_to_run:
		if action == null:
			continue
		action._finished = false
		action.run(encounterPoint)
		if action.blocking and not action.isFinished():
			await action.finished

	finish()
