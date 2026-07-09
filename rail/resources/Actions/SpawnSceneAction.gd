extends EncounterAction
class_name SpawnSceneAction

@export var nodeToSpawn : PackedScene

func run(_encounterPoint : EncounterPoint) -> void:
	finished.emit()
