extends EnemyState
class_name LostSoulInactive

func _ready() -> void:
	key = Enums.ENEMY_STATE.INACTIVE
	displayName = 'Inactive'

func enter(_previousState: Enums.ENEMY_STATE) -> void:
	parent.active = false
	parent.enemyTargetLabel.hide()

func exit(_newState: Enums.ENEMY_STATE) -> void:
	parent.setWeakness(Game.getWeaponFireType())
	parent.active = true
	parent.enemyTargetLabel.show()
