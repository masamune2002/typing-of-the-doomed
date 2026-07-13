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
	var player = Game.getPlayer()
	var tween = player.lookAtPosition(node.global_position, duration)
	if blocking and tween != null:
		# Don't await the tween itself: setFireTarget/resetCamera kill the
		# player's look tween mid-flight, and a killed tween never emits
		# finished — the await would hang the station's action queue forever.
		await player.get_tree().create_timer(duration).timeout
	finish()
