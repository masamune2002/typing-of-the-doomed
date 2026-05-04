extends EnemyState

var _target : Player

func _ready() -> void:
	key = Enums.ENEMY_STATE.MOVING

func enter(previousState : Enums.ENEMY_STATE) -> void:
	_target = Game.getPlayer()

func exit(newState : Enums.ENEMY_STATE) -> void:
	_target = null
