extends EnemyState
class_name ImpIdle

func _ready() -> void:
	key = Enums.ENEMY_STATE.IDLE
	displayName = 'Idle'

func enter(_previousState: Enums.ENEMY_STATE) -> void:
	if !parent.alive:
		return
	if parent is Imp:
		parent._currentAnimation = "idle"
		parent._currentFrameIndex = 0
	parent.look_at(Game.getPlayer().position, Vector3.UP, false)
