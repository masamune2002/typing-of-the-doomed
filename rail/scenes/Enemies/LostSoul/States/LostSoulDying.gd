extends EnemyState
class_name LostSoulDying

func _ready() -> void:
	key = Enums.ENEMY_STATE.DYING
	displayName = 'Dying'

func enter(previousState: Enums.ENEMY_STATE) -> void:
	parent.dying = true
	parent.alive = false

func exit(newState: Enums.ENEMY_STATE) -> void:
	parent.dying = false
	parent.alive = false
