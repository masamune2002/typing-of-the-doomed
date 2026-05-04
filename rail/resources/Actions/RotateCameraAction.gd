extends EncounterAction
class_name RotateCameraAction

@export var targetNode : NodePath
@export var degreeTargetY : float = 0.0
@export var degreeTargetX : float = 0.0
@export_range(1, 100) var speed : float = 50.0

func _init():
	blocking = false

func _speedToDuration() -> float:
	return 0.15 * (50.0 / max(speed, 1.0))

func run(encounterPoint : EncounterPoint) -> void:
	var duration = _speedToDuration()
	var node = encounterPoint.get_node_or_null(targetNode) if !targetNode.is_empty() else null
	if node != null:
		Game.getPlayer().lookAtPosition(node.global_position, duration)
	elif degreeTargetY != 0.0 or degreeTargetX != 0.0:
		Game.getPlayer().rotateByDegrees(degreeTargetY, degreeTargetX, duration)
