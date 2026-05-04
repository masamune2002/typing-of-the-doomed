extends EncounterAction
class_name TargetAction

@export var targetNode : NodePath
@export_range(1, 100) var speed : float = 50.0

func _init():
	blocking = false

func run(encounterPoint : EncounterPoint) -> void:
	var node = encounterPoint.get_node_or_null(targetNode) if !targetNode.is_empty() else null
	if node == null:
		push_warning("TargetAction: target node not found at %s" % [targetNode])
		return
	var player = Game.getPlayer()
	player.trackingSpeed = Player.DEFAULT_TRACKING_SPEED * (speed / 50.0)
	player.setFireTarget(node)
