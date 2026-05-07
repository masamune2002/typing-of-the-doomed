extends EncounterAction
class_name LookAtAction

@export var targetNode : NodePath
@export_range(1, 100) var speed : float = 50.0

func _speedToDuration() -> float:
	return 0.15 * (50.0 / max(speed, 1.0))

func run(encounterPoint : EncounterPoint) -> void:
	if targetNode.is_empty():
		push_warning("LookAtAction: targetNode is not set")
		finish()
		return
	var node = encounterPoint.get_node_or_null(targetNode)
	if node == null:
		push_warning("LookAtAction: node not found at path '%s'" % targetNode)
		finish()
		return
	var duration = _speedToDuration()
	var tween = Game.getPlayer().lookAtPosition(node.global_position, duration)
	if blocking and tween != null:
		await tween.finished
	finish()
