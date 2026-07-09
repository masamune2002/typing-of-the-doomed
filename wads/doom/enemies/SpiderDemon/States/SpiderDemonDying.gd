extends EnemyState
class_name SpiderDemonDying

func _ready() -> void:
	key = Enums.ENEMY_STATE.DYING
	displayName = 'Dying'

func enter(_previousState: Enums.ENEMY_STATE) -> void:
	parent.dying = true
	parent.alive = false

func exit(_newState: Enums.ENEMY_STATE) -> void:
	parent.dying = false
	parent.alive = false
