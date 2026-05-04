extends EncounterCondition
class_name VariableCondition

@export var variable_name: String = ""
@export var expected_value: String = "true"

func check(encounterPoint: EncounterPoint) -> bool:
	var current = Game.getVar(variable_name)
	if current == null:
		return false
	return current == SetVariableAction._parse_value(expected_value)
