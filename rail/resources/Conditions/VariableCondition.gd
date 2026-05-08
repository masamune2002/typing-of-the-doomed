extends EncounterCondition
class_name VariableCondition

@export var variable_name: String = ""
@export var expected_value: String = "true"

func check(marker : RailMarker) -> bool:
	var resolved = _resolve_shorthand(variable_name)
	var current = Game.getVar(resolved)
	if current != null and current == SetVariableAction._parse_value(expected_value):
		return true
	if SettingsManager != null and SettingsManager.debug_skip_doors:
		_try_auto_activate(resolved)
	return false

func _try_auto_activate(resolved_var: String) -> void:
	var tree = Engine.get_main_loop()
	if tree == null or not tree is SceneTree:
		return
	# Try interactables (doors/switches)
	var interactables = (tree as SceneTree).get_nodes_in_group("Interactables")
	for interactable in interactables:
		if not interactable is Interactable:
			continue
		if not interactable.alive:
			continue
		var prefix = interactable._var_prefix()
		var iname = interactable.interactable_name
		if iname != "" and (prefix + iname) == resolved_var:
			interactable._activate_wad_node()
			return
		if interactable.set_variable != "" and interactable.set_variable == resolved_var:
			interactable._activate_wad_node()
			return
	# Try key items (variable format: key_<key_name>)
	if resolved_var.begins_with("key_"):
		var key_name = resolved_var.substr(4)
		var items = (tree as SceneTree).get_nodes_in_group("Items")
		for item in items:
			if not item is Item:
				continue
			if not item.alive:
				continue
			if item.itemDefinition.get("effect", "") == "key" and item.itemDefinition.get("key", "") == key_name:
				item._pickup()
				return

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
