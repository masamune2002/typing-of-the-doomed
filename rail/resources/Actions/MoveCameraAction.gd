extends EncounterAction
class_name MoveCameraAction

@export var pathToFollow : NodePath
@export_range(1, 100) var speed : float = 50.0

func run(encounterPoint: EncounterPoint) -> void:
	var path: Path3D = encounterPoint.get_node_or_null(pathToFollow) as Path3D

	if path == null:
		push_warning("MoveCamera: Path3D not found at %s" % [pathToFollow])
		return

	var player = Game.getPlayer()
	var railSpeed = player.moveSpeed * (speed / 50.0)
	player.startCameraMove(path, self, railSpeed)
