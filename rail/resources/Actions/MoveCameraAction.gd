extends EncounterAction
class_name MoveCameraAction

@export var pathToFollow : NodePath

func run(encounterPoint: EncounterPoint) -> void:
	var path: Path3D = encounterPoint.get_node_or_null(pathToFollow) as Path3D

	if path == null:
		push_warning("MoveCamera: Path3D not found at %s" % [pathToFollow])
		return

	Game.getPlayer().startCameraMove(path, self)
	print('moving on ' + str(pathToFollow))
