extends EnemyState

var _target : Player

func setup():
	key = Enums.ENEMY_STATE.MOVING

func enter(previousState : Enums.ENEMY_STATE):
	_target = Game.getPlayer()

func exit(newState : Enums.ENEMY_STATE):
	_target = null
