extends EnemyState
class_name Dying

func _ready() -> void:
	key = Enums.ENEMY_STATE.DYING
	displayName = 'Dying'

func enter(previousState : Enums.ENEMY_STATE) -> void:
	parent.cancelTelegraph()
	parent.dying = true
	parent.alive = false
	parent.startedDying.emit(self)
	parent.enemyTargetLabel.hide()
	EventBus.releasePlayerTarget.emit()

	var animationName : String = parent.animationLibraryName + "/" + parent.ANIMATION_NAME_DIE
	parent.animationPlayer.play(animationName)
	var finishedName: StringName = await parent.animationPlayer.animation_finished
	if finishedName == animationName:
		parent.stateMachine.setState(Enums.ENEMY_STATE.DEAD)

func exit(newState : Enums.ENEMY_STATE) -> void:
	parent.dying = false
	parent.alive = false
