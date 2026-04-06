extends EnemyState
class_name PinkyIdle

func _ready() -> void:
	key = Enums.ENEMY_STATE.IDLE
	displayName = 'Idle'

func enter(previousState: Enums.ENEMY_STATE) -> void:
	if !parent.alive:
		return
	if parent is Pinky:
		parent._currentAnimation = "idle"
		parent._currentFrameIndex = 0
	parent.look_at(Game.getPlayer().position, Vector3.UP, false)
