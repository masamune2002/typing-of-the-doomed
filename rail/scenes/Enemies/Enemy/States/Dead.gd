extends EnemyState
class_name Dead

func _ready() -> void:
	key = Enums.ENEMY_STATE.DEAD
	displayName = 'Dead'

func enter(previousState : Enums.ENEMY_STATE) -> void:
	parent.died.emit(self)
	EventBus.enemyKilled.emit(parent)
	parent.dying = false
	parent.alive = false
