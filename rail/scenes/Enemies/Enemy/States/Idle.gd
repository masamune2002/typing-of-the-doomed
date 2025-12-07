extends EnemyState
class_name Idle

func _ready() -> void:
	key = Enums.ENEMY_STATE.IDLE
	displayName = 'Idle'

func enter(previousState : Enums.ENEMY_STATE) -> void:
	parent.look_at(Game.getPlayer().position, Vector3.UP, true)
