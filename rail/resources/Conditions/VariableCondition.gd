extends EncounterCondition
class_name VariableCondition

@export var variable_name: String = ""
@export var expected_value: String = "true"

func check(marker : RailMarker) -> bool:
	var resolved = _resolve_shorthand(variable_name)
	var current = Game.getVar(resolved)
	if current == null:
		return false
	return current == SetVariableAction._parse_value(expected_value)

static func _resolve_shorthand(s: String) -> String:
	if s.begins_with("V:"):
		return s.substr(2)
	if s.length() < 2:
		return s
	var prefix := s[0]
	var num := s.substr(1)
	if not num.is_valid_int():
		return s
	match prefix:
		"D": return "door_sector_" + num
		"L": return "lift_sector_" + num
		"F": return "floor_sector_" + num
		"E": return "exit_sector_" + num
	return s
