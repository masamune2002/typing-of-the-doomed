extends EnemyState
class_name ZombiemanInactive

func _ready() -> void:
	key = Enums.ENEMY_STATE.INACTIVE
	displayName = 'Inactive'

func enter(previousState: Enums.ENEMY_STATE) -> void:
	parent.active = false
	parent.enemyTargetLabel.hide()

func exit(newState: Enums.ENEMY_STATE) -> void:
	var fireType = Game.getWeaponFireType()
	print("ZombiemanInactive.exit: fireType=", fireType)
	parent.setWeakness(fireType)
	print("ZombiemanInactive.exit: label text=", parent.enemyTargetLabel.text)
	parent.active = true
	parent.enemyTargetLabel.show()
	print("ZombiemanInactive.exit: label visible=", parent.enemyTargetLabel.visible)
