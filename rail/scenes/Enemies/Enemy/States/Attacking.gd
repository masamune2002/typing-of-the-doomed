extends EnemyState
class_name Attacking

func _ready() -> void:
	key = Enums.ENEMY_STATE.ATTACKING
	displayName = 'Attacking'

func enter(previousState : Enums.ENEMY_STATE) -> void:
	parent.telegraphAndAttackCurrentTarget()

func exit(newState : Enums.ENEMY_STATE) -> void:
	parent.currentTarget = null
