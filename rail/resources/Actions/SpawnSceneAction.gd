extends EncounterAction
class_name SpawnSceneAction

@export var nodeToSpawn : PackedScene

func run(encounterPoint : EncounterPoint) -> void:
	finished.emit()
