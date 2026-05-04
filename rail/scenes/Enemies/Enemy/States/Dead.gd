extends EnemyState
class_name Dead

func _ready() -> void:
	key = Enums.ENEMY_STATE.DEAD
	displayName = 'Dead'

func enter(previousState : Enums.ENEMY_STATE) -> void:
	parent.dying = false
	parent.alive = false
	parent.collision_layer = 0
	parent.collision_mask = 0
	# Clear player's target if they were locked onto this enemy
	var player : Player = Game.getPlayer()
	if player != null and player._currentFireTarget == parent:
		EventBus.releasePlayerTarget.emit()
	parent.died.emit(parent)
