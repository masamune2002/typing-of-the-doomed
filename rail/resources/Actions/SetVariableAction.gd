extends EncounterAction
class_name SetVariableAction

@export var variable_name: String = ""
@export var variable_value: String = "true"

func run(encounterPoint: EncounterPoint) -> void:
	if variable_name != "":
		Game.setVar(variable_name, _parse_value(variable_value))
	finish()

static func _parse_value(val: String) -> Variant:
	if val == "true":
		return true
	if val == "false":
		return false
	if val.is_valid_int():
		return val.to_int()
	if val.is_valid_float():
		return val.to_float()
	return val
