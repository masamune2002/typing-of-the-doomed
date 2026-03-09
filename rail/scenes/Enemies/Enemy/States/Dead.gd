extends EnemyState
class_name Dead

func _ready() -> void:
	key = Enums.ENEMY_STATE.DEAD
	displayName = 'Dead'

func enter(previousState : Enums.ENEMY_STATE) -> void:
	parent.dying = false
	parent.alive = false
	parent.died.emit(parent)
	EventBus.enemyKilled.emit(parent)
