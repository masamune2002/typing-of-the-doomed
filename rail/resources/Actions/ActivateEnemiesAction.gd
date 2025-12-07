extends EncounterAction
class_name ActivateEnemiesAction

@export var enemiesToActivate : Array[NodePath]

func run(encounterPoint : EncounterPoint) -> void:
	for enemyNodePath in enemiesToActivate:
		var enemy: Enemy = encounterPoint.get_node_or_null(enemyNodePath) as Enemy

		if enemy == null:
			push_warning("ActivateEnemiesAction: Enemy not found at %s" % [enemyNodePath])
			return
		enemy.activate()
	finished.emit()
