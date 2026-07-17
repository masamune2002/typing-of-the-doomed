extends EncounterAction
class_name LookAtInteractableAction

## Aims the rail camera at whatever satisfies a condition variable — the
## door/switch/lift interactable (or key item) the player must hit to move
## on. Resolved at runtime because interactables are spawned from the WAD,
## so scene-side NodePaths can't reach them. Accepts the same shorthands as
## VariableCondition ("D39", "L28", "key_red_keycard", ...).
@export var variable_name : String = ""
@export_range(1, 100) var speed : float = 50.0

func _speedToDuration() -> float:
	return 0.15 * (50.0 / max(speed, 1.0))

func run(_encounterPoint : EncounterPoint) -> void:
	var player = Game.getPlayer()
	if variable_name == "" or player == null:
		finish()
		return
	var target = _findTarget(player)
	if target == null:
		# Nothing alive to show (door already open, key already held) — the
		# condition passes on its own, so silently skip the camera move.
		finish()
		return
	var duration = _speedToDuration()
	var tween = player.lookAtPosition(target.global_position, duration)
	if blocking and tween != null:
		# Same rule as LookAtAction: never await the tween itself — anything
		# that kills it mid-flight would strand the action queue.
		await player.get_tree().create_timer(duration).timeout
	finish()

func _findTarget(player : Player) -> Node3D:
	var resolved = VariableCondition._resolve_shorthand(variable_name)
	var tree = player.get_tree()
	# Several interactables can share a variable (a door face plus the
	# switches that drive it). The one the player will type is whichever is
	# in reach — pick the nearest alive match.
	var best : Node3D = null
	var best_dist := INF
	for node in tree.get_nodes_in_group("Interactables"):
		if not node is Interactable:
			continue
		var interactable : Interactable = node
		if not interactable.alive:
			continue
		var iname = interactable.interactable_name
		var matches = (iname != "" and interactable._var_prefix() + iname == resolved) \
			or (interactable.set_variable != "" and interactable.set_variable == resolved)
		if not matches:
			continue
		var dist = interactable.global_position.distance_to(player.global_position)
		if dist < best_dist:
			best_dist = dist
			best = interactable
	if best != null:
		return best
	if resolved.begins_with("key_"):
		var key_name = resolved.substr(4)
		for item in tree.get_nodes_in_group("Items"):
			if not item is Item:
				continue
			if not item.alive:
				continue
			if item.itemDefinition.get("effect", "") == "key" \
					and item.itemDefinition.get("key", "") == key_name:
				return item
	return null
