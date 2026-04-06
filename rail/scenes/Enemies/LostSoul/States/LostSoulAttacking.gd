extends EnemyState
class_name LostSoulAttacking

func _ready() -> void:
	key = Enums.ENEMY_STATE.ATTACKING
	displayName = 'Attacking'

func enter(previousState: Enums.ENEMY_STATE) -> void:
	if parent is LostSoul:
		parent._currentAnimation = "attack"
		parent._currentFrameIndex = 0
		parent._frameTimer = 0.0
	parent.telegraphAndAttackCurrentTarget()

func exit(newState: Enums.ENEMY_STATE) -> void:
	parent.currentTarget = null
