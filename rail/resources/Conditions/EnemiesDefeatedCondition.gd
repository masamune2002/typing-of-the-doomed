extends EncounterCondition
class_name EnemiesDefeatedCondition

@export var enemies : Array[NodePath]

func check(encounterPoint : EncounterPoint) -> bool:
	if enemies.size() == 0:
		return true
	for enemyNodePath in enemies:
		var potentialEnemy = encounterPoint.get_node_or_null(enemyNodePath)
		if potentialEnemy == null || !is_instance_valid(potentialEnemy) || potentialEnemy is not Enemy:
			continue
		var enemy : Enemy = potentialEnemy as Enemy
		if enemy.alive && !enemy.dying:
			return false
	return true
