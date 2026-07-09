extends EnemyState
class_name PinkyIdle

func _ready() -> void:
	key = Enums.ENEMY_STATE.IDLE
	displayName = 'Idle'

func enter(_previousState: Enums.ENEMY_STATE) -> void:
	if !parent.alive:
		return
	if parent is Pinky:
		parent._currentAnimation = "idle"
		parent._currentFrameIndex = 0
	var player = Game.getPlayer()
	if player != null:
		parent.look_at(player.position, Vector3.UP, false)

func _physics_process(_delta: float) -> void:
	if parent.stateMachine.currentState != self:
		return
	if !parent.alive or parent.dying or !parent.active:
		return
	var player = Game.getPlayer()
	if player == null or !is_instance_valid(player):
		return
	var distance = parent.global_position.distance_to(player.global_position)
	if distance > Pinky.MELEE_RANGE:
		parent.stateMachine.setState(Enums.ENEMY_STATE.MOVING)
