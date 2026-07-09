extends EncounterCondition
class_name VariableCondition

@export var variable_name: String = ""
@export var expected_value: String = "true"

func check(_marker : RailMarker) -> bool:
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
	# Try interactables (doors/switches). Several interactables can share a
	# name (e.g. a sector with both an S1 switch and a WR walkover line);
	# prefer switch/door trigger types - activating a walkover "closer"
	# sets the variable without ever opening the door.
	var interactables = (tree as SceneTree).get_nodes_in_group("Interactables")
	var fallback: Interactable = null
	for interactable in interactables:
		if not interactable is Interactable:
			continue
		if not interactable.alive:
			continue
		var prefix = interactable._var_prefix()
		var iname = interactable.interactable_name
		var matches = (iname != "" and (prefix + iname) == resolved_var) \
			or (interactable.set_variable != "" and interactable.set_variable == resolved_var)
		if not matches:
			continue
		var ttype = interactable.wadNode.get(WadGame.PROP_TRIGGER_TYPE) \
			if interactable.wadNode != null and is_instance_valid(interactable.wadNode) else null
		if ttype in [WADG.TTYPE.SWITCH1, WADG.TTYPE.SWITCHR, WADG.TTYPE.DOOR, WADG.TTYPE.DOOR1]:
			interactable._activate_wad_node()
			return
		if fallback == null:
			fallback = interactable
	if fallback != null:
		fallback._activate_wad_node()
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
	# Try walk triggers (levelObject group) for floor/door sector variables
	var level_objects = (tree as SceneTree).get_nodes_in_group("levelObject")
	for obj in level_objects:
		if obj.get_script() == null:
			continue
		var script_path = obj.get_script().resource_path
		if not script_path.ends_with("walkTrigger.gd"):
			continue
		var sector_node = obj.get_parent()
		if sector_node == null:
			continue
		var sector_name = sector_node.name
		var clean_name = sector_name.replace(" ", "_")
		var candidate_floor = "floor_" + clean_name
		var candidate_door = "door_" + clean_name
		if obj.get("disabled") == true:
			continue
		if resolved_var == candidate_floor or resolved_var == candidate_door:
			var player = Game.getPlayer()
			if player != null and obj.has_method("_fire"):
				obj._fire(player)
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
